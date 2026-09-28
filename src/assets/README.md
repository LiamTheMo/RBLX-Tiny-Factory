# Tiny Factory assets

`src/assets` maps to `ReplicatedStorage.Assets`. Use PascalCase folders and descriptive asset names.

- `Models/3D`: reusable Tiny Factory low-poly environment assets from the 6×6 Meshy asset sheet.
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

The 36 environment GLBs are single-mesh, single-primitive, single-material
assets. Their embedded JPEG textures have been reduced to 1024×1024 while
preserving the original colors and geometry. The 3D folder also contains
`AssetCatalog.luau`, which Rojo includes under `ReplicatedStorage.Assets`; the
main-only import workflow uploads each GLB as its own Roblox Model, records its
asset ID in the catalog, and the server showcase loads each model onto a large
grass baseplate. The source GLBs are kept in this folder for repeatable imports.
