# Figma inventory and HUD validation

The reference layout is implemented with the original Figma coin, dice, chest, gear, category icons, rarity badges, frames and button artwork. The top Workshop Amber title is omitted as requested. The inventory shows actual owned machines, counts and odds with live native model previews. Four tabs filter droppers, upgraders, sellers and boosters. Placement, return, move, recycling, capacity and free-roll contracts remain server authoritative.

## Completed / Passed

- Desktop HUD: coin at top left, gear at top right, Inventory at bottom left, Roll at bottom center, three-column inventory at right.
- Responsive safe-area measurement, proportional desktop scaling, compact landscape scrolling cards, portrait geometry support and separate bottom controls.
- Phone controls have at least 44 logical pixels of height; category captions shrink within their bounds.
- Original exports retained with uploaded texture dimensions and permanent IDs in src/assets/UI/README.md.
- Studio rendering inspected using the laptop and iPhone 17 Pro landscape simulator. Top banner absent; original Figma artwork visible. Roll activation and category filtering observed. Simulator reset after testing.
- Luau compilation, ten pure Luau suites, seven Python tests, 72 model-source validations, Rojo build and Git whitespace check passed.
- Shared machine model builder avoids duplicating server/client visuals.

## Requires Manual Validation

- Owner visual acceptance, readable text and touch feel on physical devices; compact cards intentionally use one scrolling column instead of shrinking the desktop grid.
- Full contextual place/move/return/recycle and capacity purchase loop, reconnect and multiplayer on a published main build.
- Updated full Studio smoke harness through Studio RunScript. Its former invalid GuiButton Activate call is replaced with the public category selection method.
- Fresh published-session image loading using standard Image assets. Studio verification uses authorized EditableImage content because the legacy loader cached earlier permission failures.
- Live deployment is gated by the repository's existing main-only publishing configuration.

## Incomplete / Needs Work

- Owner acceptance and the deployed/manual checks above remain open. This UI change does not close the broader MVP release gates.
