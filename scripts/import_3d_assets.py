#!/usr/bin/env python3
"""Validate and import Tiny Factory's reusable GLB models into Roblox."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs/assets/3d-model-assets.json"
DEFAULT_SOURCE_DIR = ROOT / "src/assets/Models/3D"
DEFAULT_CATALOG = DEFAULT_SOURCE_DIR / "AssetCatalog.luau"

GLB_MAGIC = 0x46546C67
GLB_JSON_CHUNK = 0x4E4F534A
GLB_BIN_CHUNK = 0x004E4942
ASSET_API = "https://apis.roblox.com/assets/v1/"
CLOUD_API = "https://apis.roblox.com/cloud/v2/"
ASSETS_PER_PACK = 36
MAX_PACK_COUNT = 2
MAX_ASSET_COUNT = ASSETS_PER_PACK * MAX_PACK_COUNT
MAX_TOTAL_BYTES = 60_000_000
MAX_FILE_BYTES = 2_000_000
MAX_TRIANGLES = 13_000
MAX_TEXTURE_DIMENSION = 1024
POLL_ATTEMPTS = 30
POLL_INTERVAL_SECONDS = 10


class AssetImportError(RuntimeError):
    """A validation or Roblox asset import failure safe to show in CI logs."""


def display_name(key: str) -> str:
    key_without_pack = re.sub(r"^s[1-9][0-9]*_", "", key)
    return re.sub(r"^r[1-6]c[1-6]_", "", key_without_pack).replace("_", " ").title()


def jpeg_dimensions(data: bytes) -> tuple[int, int]:
    if not data.startswith(b"\xff\xd8"):
        raise AssetImportError("embedded texture is not a JPEG")

    offset = 2
    while offset < len(data):
        if data[offset] != 0xFF:
            offset += 1
            continue
        while offset < len(data) and data[offset] == 0xFF:
            offset += 1
        if offset >= len(data):
            break

        marker = data[offset]
        offset += 1
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7 or marker == 0x01:
            continue
        if offset + 2 > len(data):
            break
        segment_length = struct.unpack_from(">H", data, offset)[0]
        if segment_length < 2 or offset + segment_length > len(data):
            break
        if marker in {
            0xC0,
            0xC1,
            0xC2,
            0xC3,
            0xC5,
            0xC6,
            0xC7,
            0xC9,
            0xCA,
            0xCB,
            0xCD,
            0xCE,
            0xCF,
        }:
            height, width = struct.unpack_from(">HH", data, offset + 3)
            return width, height
        offset += segment_length

    raise AssetImportError("could not read embedded JPEG dimensions")


def read_glb(path: Path) -> tuple[dict[str, Any], bytes]:
    data = path.read_bytes()
    if len(data) < 20:
        raise AssetImportError(f"{path.name} is too small to be a GLB")
    magic, version, total_length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC or version != 2 or total_length != len(data):
        raise AssetImportError(f"{path.name} has an invalid GLB v2 header")

    offset = 12
    json_bytes: bytes | None = None
    binary: bytes | None = None
    while offset < len(data):
        if offset + 8 > len(data):
            raise AssetImportError(f"{path.name} has a truncated GLB chunk header")
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        start = offset + 8
        end = start + chunk_length
        if end > len(data):
            raise AssetImportError(f"{path.name} has a truncated GLB chunk")
        if chunk_type == GLB_JSON_CHUNK:
            if json_bytes is not None:
                raise AssetImportError(f"{path.name} has more than one JSON chunk")
            json_bytes = data[start:end]
        elif chunk_type == GLB_BIN_CHUNK:
            if binary is not None:
                raise AssetImportError(f"{path.name} has more than one BIN chunk")
            binary = data[start:end]
        offset = end

    if json_bytes is None or binary is None:
        raise AssetImportError(f"{path.name} must contain JSON and BIN chunks")
    try:
        document = json.loads(json_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AssetImportError(f"{path.name} has invalid embedded glTF JSON") from error
    return document, binary


def inspect_asset(record: dict[str, Any], source_dir: Path) -> dict[str, Any]:
    key = record.get("key")
    filename = record.get("file")
    key_match = re.fullmatch(r"(?:s([1-9][0-9]*)_)?r([1-6])c([1-6])_[a-z0-9_]+", key) if isinstance(key, str) else None
    if key_match is None:
        raise AssetImportError(f"invalid asset key: {key!r}")
    if not isinstance(filename, str) or Path(filename).name != filename or not filename.endswith(".glb"):
        raise AssetImportError(f"invalid GLB filename for {key}")
    if filename != f"{key}.glb":
        raise AssetImportError(f"asset key and filename do not match: {key} / {filename}")

    key_pack = int(key_match.group(1) or 1)
    pack = record.get("pack", key_pack)
    if not isinstance(pack, int) or isinstance(pack, bool) or pack != key_pack or not 1 <= pack <= MAX_PACK_COUNT:
        raise AssetImportError(f"reference-sheet pack does not match {key}")
    row, column = int(key_match.group(2)), int(key_match.group(3))
    if record.get("row") != row or record.get("column") != column:
        raise AssetImportError(f"grid coordinates do not match {key}")

    model_path = source_dir / filename
    if not model_path.is_file():
        raise AssetImportError(f"missing source model: {model_path}")
    file_bytes = model_path.stat().st_size
    if file_bytes > MAX_FILE_BYTES:
        raise AssetImportError(f"{filename} exceeds the 2 MB optimized source budget")
    document, binary = read_glb(model_path)

    meshes = document.get("meshes")
    primitives = meshes[0].get("primitives") if isinstance(meshes, list) and len(meshes) == 1 else None
    if not isinstance(primitives, list) or len(primitives) != 1:
        raise AssetImportError(f"{filename} must contain exactly one mesh and one primitive")
    materials = document.get("materials")
    textures = document.get("textures")
    images = document.get("images")
    if not isinstance(materials, list) or len(materials) != 1:
        raise AssetImportError(f"{filename} must contain exactly one material")
    if not isinstance(textures, list) or len(textures) != 1 or not isinstance(images, list) or len(images) != 1:
        raise AssetImportError(f"{filename} must contain one embedded texture")
    if primitives[0].get("material") != 0:
        raise AssetImportError(f"{filename} primitive is not using its single material")
    base_color = materials[0].get("pbrMetallicRoughness", {}).get("baseColorTexture", {})
    if base_color.get("index") != 0 or textures[0].get("source") != 0:
        raise AssetImportError(f"{filename} material is not connected to its embedded texture")

    accessors = document.get("accessors", [])
    index_accessor = primitives[0].get("indices")
    if not isinstance(index_accessor, int) or index_accessor >= len(accessors):
        raise AssetImportError(f"{filename} does not have a valid triangle index buffer")
    index_count = accessors[index_accessor].get("count")
    if not isinstance(index_count, int) or index_count % 3 != 0:
        raise AssetImportError(f"{filename} has an invalid triangle index count")
    triangles = index_count // 3
    if triangles <= 0 or triangles > MAX_TRIANGLES:
        raise AssetImportError(f"{filename} has an unexpected triangle count: {triangles}")

    image = images[0]
    if image.get("mimeType") != "image/jpeg":
        raise AssetImportError(f"{filename} texture must use JPEG encoding")
    view_index = image.get("bufferView")
    views = document.get("bufferViews", [])
    if not isinstance(view_index, int) or view_index >= len(views):
        raise AssetImportError(f"{filename} texture has an invalid GLB buffer view")
    view = views[view_index]
    if view.get("buffer", 0) != 0:
        raise AssetImportError(f"{filename} texture uses an unsupported GLB buffer")
    image_start = view.get("byteOffset", 0)
    image_end = image_start + view.get("byteLength", -1)
    if not isinstance(image_start, int) or not isinstance(image_end, int) or image_start < 0 or image_end > len(binary):
        raise AssetImportError(f"{filename} texture is outside its GLB binary chunk")
    width, height = jpeg_dimensions(binary[image_start:image_end])
    if max(width, height) > MAX_TEXTURE_DIMENSION:
        raise AssetImportError(f"{filename} texture is larger than 1024×1024")

    source_sha256 = hashlib.sha256(model_path.read_bytes()).hexdigest()
    if record.get("sourceSha256") != source_sha256:
        raise AssetImportError(f"source SHA-256 is stale for {filename}; update the asset manifest")
    asset_id = record.get("assetId")
    if not isinstance(asset_id, int) or isinstance(asset_id, bool) or asset_id < 0:
        raise AssetImportError(f"invalid Roblox asset ID for {key}")
    asset_sha256 = record.get("assetSha256", "")
    if asset_sha256 and not re.fullmatch(r"[0-9a-f]{64}", asset_sha256):
        raise AssetImportError(f"invalid imported source SHA-256 for {key}")
    operation_sha256 = record.get("operationSha256", "")
    if operation_sha256 and not re.fullmatch(r"[0-9a-f]{64}", operation_sha256):
        raise AssetImportError(f"invalid pending operation SHA-256 for {key}")
    return {
        "key": key,
        "file": filename,
        "pack": pack,
        "row": row,
        "column": column,
        "displayName": display_name(key),
        "assetId": asset_id,
        "sourceSha256": source_sha256,
        "assetSha256": asset_sha256,
        "triangles": triangles,
        "textureWidth": width,
        "textureHeight": height,
        "fileBytes": file_bytes,
    }


def render_catalog(assets: list[dict[str, Any]]) -> str:
    lines = ["--!strict", "-- Generated from docs/assets/3d-model-assets.json.", "return {"]
    for asset in assets:
        lines.extend(
            [
                "\t{",
                f"\t\tKey = {json.dumps(asset['key'])},",
                f"\t\tDisplayName = {json.dumps(asset['displayName'])},",
                f"\t\tFileName = {json.dumps(asset['file'])},",
                f"\t\tAssetId = {asset['assetId']},",
                f"\t\tPack = {asset.get('pack', 1)},",
                f"\t\tRow = {asset['row']},",
                f"\t\tColumn = {asset['column']},",
                f"\t\tSourceSha256 = {json.dumps(asset['sourceSha256'])},",
                "\t},",
            ]
        )
    lines.append("}")
    return "\n".join(lines) + "\n"


def load_and_validate(manifest_path: Path, source_dir: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise AssetImportError(f"could not read asset manifest: {manifest_path}") from error
    if manifest.get("schemaVersion") != 1:
        raise AssetImportError("unsupported 3D asset manifest schema")
    records = manifest.get("assets")
    if (
        not isinstance(records, list)
        or not records
        or len(records) > MAX_ASSET_COUNT
        or len(records) % ASSETS_PER_PACK != 0
    ):
        raise AssetImportError(f"expected one or two complete {ASSETS_PER_PACK}-asset reference sheets")
    if manifest.get("assetCount", len(records)) != len(records):
        raise AssetImportError("manifest assetCount does not match its asset records")
    pack_count = len(records) // ASSETS_PER_PACK

    assets = [inspect_asset(record, source_dir) for record in records]
    assets.sort(key=lambda asset: (asset["pack"], asset["row"], asset["column"]))
    expected_coordinates = {(row, column) for row in range(1, 7) for column in range(1, 7)}
    for pack in range(1, pack_count + 1):
        coordinates = {
            (asset["row"], asset["column"]) for asset in assets if asset["pack"] == pack
        }
        if coordinates != expected_coordinates:
            raise AssetImportError(f"asset pack {pack} must contain every cell in its 6×6 grid")
    if {asset["pack"] for asset in assets} != set(range(1, pack_count + 1)):
        raise AssetImportError("asset packs must be numbered consecutively starting at one")
    if len({asset["key"] for asset in assets}) != len(assets):
        raise AssetImportError("asset keys must be unique across all reference sheets")
    actual_files = {path.name for path in source_dir.glob("*.glb")}
    expected_files = {asset["file"] for asset in assets}
    if actual_files != expected_files:
        raise AssetImportError("the 3D asset folder and manifest do not contain the same GLB files")
    total_bytes = sum(asset["fileBytes"] for asset in assets)
    if total_bytes > MAX_TOTAL_BYTES:
        raise AssetImportError("optimized 3D GLBs exceed the 60 MB combined source budget")
    return manifest, assets


def request_json(
    url: str,
    api_key: str,
    *,
    method: str = "GET",
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
    retries: int = 5,
) -> dict[str, Any]:
    request_headers = {"x-api-key": api_key, "Accept": "application/json"}
    if headers:
        request_headers.update(headers)
    for attempt in range(1, retries + 1):
        request = urllib.request.Request(url, data=body, headers=request_headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                response_body = response.read()
            try:
                return json.loads(response_body.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise AssetImportError("Roblox API returned invalid JSON") from error
        except urllib.error.HTTPError as error:
            response_body = error.read().decode("utf-8", errors="replace")
            if error.code == 429 or 500 <= error.code < 600:
                if attempt < retries:
                    retry_after = error.headers.get("Retry-After")
                    try:
                        delay = min(60, max(1, int(retry_after))) if retry_after else min(30, 2**attempt)
                    except ValueError:
                        delay = min(30, 2**attempt)
                    print(f"Roblox API returned HTTP {error.code}; retrying in {delay}s.", flush=True)
                    time.sleep(delay)
                    continue
            message = response_body[:500]
            raise AssetImportError(f"Roblox API request failed with HTTP {error.code}: {message}") from error
        except urllib.error.URLError as error:
            if attempt < retries:
                delay = min(30, 2**attempt)
                print(f"Roblox API connection failed; retrying in {delay}s.", flush=True)
                time.sleep(delay)
                continue
            raise AssetImportError(f"Roblox API connection failed: {error.reason}") from error
    raise AssetImportError("Roblox API request did not complete")


def resolve_creator(universe_id: str, api_key: str) -> dict[str, int]:
    universe = request_json(f"{CLOUD_API}universes/{universe_id}", api_key)
    group_path = universe.get("group") or ""
    user_path = universe.get("user") or ""
    if bool(group_path) == bool(user_path):
        raise AssetImportError("Roblox Cloud universe response did not identify exactly one owner")
    creator_path = group_path or user_path
    creator_id_text = creator_path.rstrip("/").split("/")[-1]
    if not creator_id_text.isdigit() or int(creator_id_text) <= 0:
        raise AssetImportError("Roblox universe owner ID is not a positive integer")
    return {"groupId" if group_path else "userId": int(creator_id_text)}


def multipart_body(request_data: dict[str, Any], model_path: Path) -> tuple[bytes, str]:
    boundary = "----TinyFactory3D" + hashlib.sha256(os.urandom(32)).hexdigest()[:24]
    prefix = (
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="request"\r\n'
        "Content-Type: application/json\r\n\r\n"
        + json.dumps(request_data, separators=(",", ":"))
        + "\r\n"
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="fileContent"; filename="{model_path.name}"\r\n'
        "Content-Type: model/gltf-binary\r\n\r\n"
    ).encode("utf-8")
    suffix = f"\r\n--{boundary}--\r\n".encode("ascii")
    return prefix + model_path.read_bytes() + suffix, f"multipart/form-data; boundary={boundary}"


def create_asset(
    asset: dict[str, Any], source_dir: Path, creator: dict[str, int], api_key: str
) -> str:
    request_data = {
        "assetType": "Model",
        "displayName": f"Tiny Factory - {asset['displayName']}",
        "description": (
            "Reusable single-mesh low-poly environment model for Tiny Factory. "
            f"6x6 reference sheet {asset['pack']} cell R{asset['row']}C{asset['column']}."
        ),
        "creationContext": {"creator": creator},
    }
    body, content_type = multipart_body(request_data, source_dir / asset["file"])
    operation = request_json(
        ASSET_API + "assets",
        api_key,
        method="POST",
        body=body,
        headers={"Content-Type": content_type},
    )
    path = operation.get("path")
    if not isinstance(path, str) or not path.startswith("operations/"):
        raise AssetImportError(f"Roblox did not return a valid import operation for {asset['file']}")
    return path


def poll_operation(operation_path: str, api_key: str) -> int:
    if not operation_path.startswith("operations/") or ".." in operation_path:
        raise AssetImportError("Roblox import operation path is invalid")
    for attempt in range(1, POLL_ATTEMPTS + 1):
        status = request_json(urllib.parse.urljoin(ASSET_API, operation_path), api_key)
        if status.get("done") is True:
            if status.get("error"):
                raise AssetImportError("Roblox could not process a GLB Model asset")
            asset_id = (status.get("response") or {}).get("assetId")
            try:
                parsed_id = int(asset_id)
            except (TypeError, ValueError) as error:
                raise AssetImportError("Roblox completed an import without returning an asset ID") from error
            if parsed_id <= 0:
                raise AssetImportError("Roblox returned an invalid Model asset ID")
            return parsed_id
        if attempt < POLL_ATTEMPTS:
            time.sleep(POLL_INTERVAL_SECONDS)
    raise AssetImportError(f"Roblox import operation timed out: {operation_path}")


def write_state(manifest_path: Path, catalog_path: Path, manifest: dict[str, Any], assets: list[dict[str, Any]]) -> None:
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    catalog_path.write_text(render_catalog(assets), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--validate-only", action="store_true", help="validate source files and the Rojo catalog without uploading")
    parser.add_argument("--sync-catalog-only", action="store_true", help="regenerate the Rojo catalog without uploading")
    parser.add_argument("--require-imported", action="store_true", help="fail unless every current source has a Roblox Model asset ID")
    args = parser.parse_args()

    try:
        manifest, assets = load_and_validate(args.manifest, args.source_dir)
        if args.validate_only:
            if args.require_imported and any(
                asset["assetId"] <= 0 or asset["assetSha256"] != asset["sourceSha256"] for asset in assets
            ):
                raise AssetImportError("every current 3D source must have a matching imported Roblox Model ID")
            expected_catalog = render_catalog(assets)
            if not args.catalog.is_file() or args.catalog.read_text(encoding="utf-8") != expected_catalog:
                raise AssetImportError("AssetCatalog.luau is out of date; regenerate it from the JSON manifest")
            print(
                f"Validated {len(assets)} single-mesh assets, "
                f"{sum(asset['fileBytes'] for asset in assets):,} bytes total, "
                f"{min(asset['triangles'] for asset in assets)}–{max(asset['triangles'] for asset in assets)} triangles each."
            )
            return 0

        if args.sync_catalog_only:
            write_state(args.manifest, args.catalog, manifest, assets)
            print(f"Wrote Rojo asset catalog for {len(assets)} source models.")
            return 0

        api_key = os.environ.get("ROBLOX_API_KEY", "")
        universe_id = os.environ.get("ROBLOX_UNIVERSE_ID", "")
        if not api_key or not universe_id:
            raise AssetImportError("ROBLOX_API_KEY and ROBLOX_UNIVERSE_ID must be configured for import")
        creator = resolve_creator(universe_id, api_key)
        imported_count = 0
        reused_count = 0

        for asset in assets:
            record = next(item for item in manifest["assets"] if item["key"] == asset["key"])
            if record["assetId"] > 0 and record.get("assetSha256") == asset["sourceSha256"]:
                reused_count += 1
                continue

            operation_path = record.get("operationPath")
            if operation_path and record.get("operationSha256") != asset["sourceSha256"]:
                record.pop("operationPath", None)
                record.pop("operationSha256", None)
                operation_path = None
            if not operation_path:
                operation_path = create_asset(asset, args.source_dir, creator, api_key)
                record["operationPath"] = operation_path
                record["operationSha256"] = asset["sourceSha256"]
                write_state(args.manifest, args.catalog, manifest, assets)
            print(f"Importing {asset['key']} ({asset['fileBytes']:,} bytes).", flush=True)
            asset_id = poll_operation(operation_path, api_key)
            record["assetId"] = asset_id
            record["assetSha256"] = asset["sourceSha256"]
            record.pop("operationPath", None)
            record.pop("operationSha256", None)
            asset["assetId"] = asset_id
            write_state(args.manifest, args.catalog, manifest, assets)
            imported_count += 1
            print(f"Imported {asset['key']} as Roblox Model {asset_id}.", flush=True)

        print(f"3D asset import complete: {imported_count} uploaded, {reused_count} already current.")
        return 0
    except AssetImportError as error:
        print(f"3D asset import failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
