import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts import import_3d_assets


class AssetImportTests(unittest.TestCase):
    def test_multipart_upload_keeps_glb_bytes_and_json_request(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            model_path = Path(temp_dir) / "r1c1_grass_platform.glb"
            model_bytes = b"glTF\x02\x00\x00\x00-test-model"
            model_path.write_bytes(model_bytes)
            request_data = {
                "assetType": "Model",
                "creationContext": {"creator": {"userId": 123}},
            }

            body, content_type = import_3d_assets.multipart_body(request_data, model_path)

        self.assertIn("multipart/form-data; boundary=", content_type)
        self.assertIn(b'name="request"', body)
        self.assertIn(b"application/json", body)
        self.assertIn(json.dumps(request_data, separators=(",", ":")).encode(), body)
        self.assertIn(b'name="fileContent"; filename="r1c1_grass_platform.glb"', body)
        self.assertIn(b"model/gltf-binary", body)
        self.assertIn(model_bytes, body)

    @patch("scripts.import_3d_assets.request_json")
    def test_poll_operation_returns_completed_model_id(self, request_json):
        request_json.return_value = {"done": True, "response": {"assetId": "123456"}}

        asset_id = import_3d_assets.poll_operation("operations/example", "secret")

        self.assertEqual(asset_id, 123456)
        request_json.assert_called_once_with(
            "https://apis.roblox.com/assets/v1/operations/example", "secret"
        )

    @patch("scripts.import_3d_assets.request_json")
    def test_poll_operation_rejects_failed_asset_import(self, request_json):
        request_json.return_value = {"done": True, "error": {"message": "invalid model"}}

        with self.assertRaises(import_3d_assets.AssetImportError):
            import_3d_assets.poll_operation("operations/example", "secret")

    def test_render_catalog_includes_reusable_asset_metadata(self):
        source_hash = "a" * 64
        rendered = import_3d_assets.render_catalog(
            [
                {
                    "key": "r1c1_grass_platform",
                    "displayName": "Grass Platform",
                    "file": "r1c1_grass_platform.glb",
                    "assetId": 123456,
                    "row": 1,
                    "column": 1,
                    "sourceSha256": source_hash,
                }
            ]
        )

        self.assertIn('Key = "r1c1_grass_platform"', rendered)
        self.assertIn("AssetId = 123456", rendered)
        self.assertIn(f'SourceSha256 = "{source_hash}"', rendered)

    def test_import_saves_operation_checkpoint_and_reusable_model_id(self):
        source_hash = "b" * 64
        record = {
            "key": "r1c1_grass_platform",
            "file": "r1c1_grass_platform.glb",
            "row": 1,
            "column": 1,
            "assetId": 0,
            "sourceSha256": source_hash,
            "assetSha256": "",
        }
        asset = {
            "key": record["key"],
            "file": record["file"],
            "row": 1,
            "column": 1,
            "displayName": "Grass Platform",
            "assetId": 0,
            "sourceSha256": source_hash,
            "assetSha256": "",
            "fileBytes": 100,
        }
        manifest = {"schemaVersion": 1, "assets": [record]}

        with (
            patch.object(import_3d_assets, "load_and_validate", return_value=(manifest, [asset])),
            patch.object(import_3d_assets, "resolve_creator", return_value={"userId": 123}),
            patch.object(import_3d_assets, "create_asset", return_value="operations/grass"),
            patch.object(import_3d_assets, "poll_operation", return_value=123456),
            patch.object(import_3d_assets, "write_state") as write_state,
            patch.dict(os.environ, {"ROBLOX_API_KEY": "test-key", "ROBLOX_UNIVERSE_ID": "321"}),
            patch("sys.argv", ["import_3d_assets.py"]),
        ):
            exit_code = import_3d_assets.main()

        self.assertEqual(exit_code, 0)
        self.assertEqual(record["assetId"], 123456)
        self.assertEqual(record["assetSha256"], source_hash)
        self.assertNotIn("operationPath", record)
        self.assertEqual(asset["assetId"], 123456)
        self.assertEqual(write_state.call_count, 2)

    def test_import_reuses_asset_when_its_source_hash_matches(self):
        source_hash = "c" * 64
        record = {
            "key": "r1c1_grass_platform",
            "assetId": 123456,
            "sourceSha256": source_hash,
            "assetSha256": source_hash,
        }
        asset = {
            "key": record["key"],
            "sourceSha256": source_hash,
            "assetSha256": source_hash,
            "assetId": 123456,
        }
        manifest = {"schemaVersion": 1, "assets": [record]}

        with (
            patch.object(import_3d_assets, "load_and_validate", return_value=(manifest, [asset])),
            patch.object(import_3d_assets, "resolve_creator"),
            patch.object(import_3d_assets, "create_asset") as create_asset,
            patch.object(import_3d_assets, "poll_operation") as poll_operation,
            patch.object(import_3d_assets, "write_state") as write_state,
            patch.dict(os.environ, {"ROBLOX_API_KEY": "test-key", "ROBLOX_UNIVERSE_ID": "321"}),
            patch("sys.argv", ["import_3d_assets.py"]),
        ):
            exit_code = import_3d_assets.main()

        self.assertEqual(exit_code, 0)
        create_asset.assert_not_called()
        poll_operation.assert_not_called()
        write_state.assert_not_called()


if __name__ == "__main__":
    unittest.main()
