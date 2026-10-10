# Workshop Amber island map

## Scope

Reference images 4 and 5 guide the map: cheerful grass, sandstone coast,
timber workshops, garden vegetation and docks. Images 1–3 are the Workshop
Amber UI reference sheets; their palette informs lantern and timber accents.
This change implements the map and factory integration, not a UI replacement.

`IslandWorldBuilder` creates editable native Roblox parts without external
mesh loading. Six starter islands surround a three-tier central mesa, with
a large treehouse, two cave shelters, decorative crystals and a waterfall.
Boardwalks connect the islands; ramps reach the treehouse deck. Each starter
island has a cabin, garden terrace, flowers, trees, dock and clear factory area.

`IslandWorldConfig` is the source of truth for map identity, ground/water
height, six plot positions and free-island allocation. The server assigns
and releases islands, sets the player's respawn location, and returns players
who fall below the lagoon to their own island. The existing five-slot route,
inventory, payouts and save schema remain intact. Configure the Roblox place
for six players; a seventh player is redirected by a full-server kick message.

The map is constructed before the gameplay services start. Studio edit mode
can preview it by requiring `IslandWorldBuilder` and calling `build()` through
the Studio MCP. Rojo builds include the source; map generation occurs at
runtime. The model is named `WorkshopAmberIslands` and uses stable island names.

## Completed / Passed

- Read all 42 Markdown files present before this change.
- Nine Luau suites, including island separation, full-capacity handling and
  released-slot reuse.
- Luau source/test compilation.
- Seventy-two source GLB validations and seven Python import-helper tests.
- Rojo place build and diff whitespace review.
- Inserted the map into the user-confirmed Studio place 116499398973334.
- Studio server smoke: 150 ground samples, 4,468 anchored map parts, assigned
  island respawn, character reload, lagoon fall recovery and nine completed sales.
- Studio pathfinding: all six island-to-hub routes and all seven boardwalk/ramp
  segments leading to the treehouse deck succeeded.
- Removed the temporary server QA script after the test. The repeatable source
  remains in `tests/studio/IslandMapSmoke.server.luau`, outside the Rojo game tree.
- Inspected Studio screenshots of the world and a starter island. Invisible
  collision strips bridge wedge seams; elevated access routes avoid solid cliffs
  and the central trunk.

## Requires Manual Validation

Studio engine and pathfinding checks passed on 2026-10-10. These are automated
Studio checks, not owner visual acceptance or device/multiplayer measurements.

- Owner visual acceptance of shores, gardens, tree silhouettes and map scale.
- Human walkthrough of every boardwalk/ramp and cabin/cave shelter.
- Check factory ground elevation, plot camera clearance and all five click areas.
- Test reconnect and initial spawn on a fresh published server.
- Check six simultaneous players, one departure and slot reuse by a new player.
- Run the updated Studio smoke test on a built local place.
- Measure construction time, frame time and memory on desktop and phone/tablet.
- Confirm published main validation and deployment before deployed acceptance.

## Incomplete / Needs Work

Visual acceptance, device profiling and deployed acceptance remain open. UI atlas
integration, machine art and audio stay in their separately documented MVP phases.
