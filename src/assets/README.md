# Tiny Factory assets

`src/assets` maps to `ReplicatedStorage.Assets`. Use PascalCase folders and descriptive asset names.

- `Models/3D`: reusable Tiny Factory low-poly environment assets from two 6×6 Meshy sheets.
- `Models/2D`: factory, machine, and item concept/modeling references.
- `Images/Homepage`: icons and thumbnails.
- `Images/UI`: interface assets when needed.

Phase 1 uses simple generated/placeholder geometry: a producer, a processor, a
seller, a path, and a cube-like item. Adding an asset does not automatically
replace placeholder geometry; the machine definition and runtime must remain
valid without optional art.

Prioritize readable silhouettes, clear item transformations, simple collision
proxies, and a low-noise visual language. Final machine and environment art is
v1 polish work after the deterministic simulation is proven.

The 72 environment GLBs are single-mesh, single-primitive, single-material
assets. Their embedded JPEG textures are limited to 1024×1024 while preserving
the original colors and geometry. The 3D folder also contains
`AssetCatalog.luau`, which Rojo includes under `ReplicatedStorage.Assets`; the
optional import helper can upload each GLB as its own Roblox Model and record its
asset ID in the catalog. The asset showcase is disabled for the temporary
baseplate prototype. The source GLBs remain here for later map work.
