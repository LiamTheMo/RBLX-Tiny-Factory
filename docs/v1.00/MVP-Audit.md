# v1.00 MVP Audit — 2026-10-07

## Verdict

**Incomplete / Needs Work.** v1.00 is the active MVP completion effort. Passing code checks does not mean the game is visually finished, fun, or ready for public release. Finish the world, machines, presentation, balance, and deployed playtests before starting v2.00 logistics.

## Branch reconciliation

Before this pass, `v1.00` was 123 commits behind deployed `main`; documentation and the runtime label called v2.00 active. Existing machine/booster/persistence fixes were brought forward into a temporary branch originating from v1.00 without rewriting any version history. The existing v2.00 branch remains a permanent historical checkpoint; its name is not evidence that the planned graph phases are complete. Runtime build label now identifies the active MVP as v1.00; save schema remains 4 and machine IDs remain stable.

## Completed / Passed

| Area | Evidence and limits |
| --- | --- |
| Core simulation | `FactorySimulation`: bounded deterministic line, processing, cube caps, value bounds, server-owned sales. Pure tests pass; engine behavior still needs testing. |
| Rolling | `EconomyRules`: rarity draw then item weight; exact whole-roll odds and Luck adjustment. No client-selected outcomes. |
| Catalog | Eight rollable droppers and eight rollable sellers in each of Common, Uncommon, Rare, Epic, Legendary; 80 combined, plus existing upgraders and nonrollable starter. See `Machine-Catalog.md`. |
| Placement / inventory | Shared rules and server transactions; producer at start, three processor areas, dedicated terminal seller bay; category inventory and recycling. |
| Saving | Schema 4, current-state autosaves, session leases, rejoin layout state, leave/shutdown paths; sanitization and migration tests pass. |
| Economy | Free rolls on a three-second cooldown; Coins fund two capacity purchases; bounded two-decimal payouts; no recycling Coin faucet. |
| Feedback / boosters | Hover value breakdown, floating sale totals, roll reveal, Coin sale multiplier and Luck boosters are implemented. Visual quality still provisional. |
| Seller defects fixed in this pass | Missing `CubeTypeDefinitions` import for rarity payouts fixed; sale intervals now enforced server-side. Rejected cooldown sales retain item and wallet; repeat sale cannot double-credit. |
| Automated validation | Eight Luau suites, seven Python tests, asset manifest/source validation, Luau compilation, Rojo place build. Compilation is not a strict type/lint pass or an engine test. |
| Deployment policy | Workflow runs on major pushes only; publishing is main-only and depends on validation. Last pre-change main run was successful. Check the new run before declaring deployment complete. |

## Incomplete / Needs Work

| Priority | Finding | Concrete completion requirement |
| --- | --- | --- |
| P0 | Playable world is a prototype | `default.project.json` still builds `PrototypeBaseplate` and `PrototypeSpawn`; map directory contains no modeled island scene. Integrate the water-island setting, six readable plots, safe spawn/path, central rocky terraced island and large treehouse. Test collision, scale, anchoring, loading and sightlines. |
| P0 | Machine models remain proof-of-concept | `MachineModelBuilder` uses primitive housings and `MachineVisualConfig` fills missing IDs with generic variants. Build distinct family silhouettes and rarity detail progression for droppers/sellers/upgraders, without hopper droppers; sellers need a clear conveyor-fed opening. Reuse art families to keep 80 variants manageable. |
| P0 | Model sources are not a finished environment | 72 GLB sources validate, but a source manifest is not an assembled playable map. Individual sources range from 2,906–12,331 triangles: budget repeated assets, simplify/decorate selectively, and verify actual Roblox imports. |
| P1 | Audio pass missing | No sound creation or SoundId setup found in active client/server services. Add licensed drop, processing, sale, roll rarity, placement, and soft ambience with mute/volume controls and overlap caps. |
| P1 | Catalog/economy needs pacing work | 80 dropper/seller variants dilute individual acquisition chances. Preserve low-rarity usefulness, test speed/value/type/streak tradeoffs, and tune 25/100 expansion costs from sessions. Eight entries per category per rarity is content coverage, not balance approval. |
| P1 | Inventory detail readability | Rows use descriptions; older definitions do not consistently expose all spawn/value/type/cooldown stats in their text. Add readable stat summaries, search/sort if needed, and confirm long descriptions do not clip on phone. |
| P1 | Effects and machine behavior communication | Generic details/colors do not prove a cube's type or transformation is understandable. Add limited family cues, activation animation, understandable sale intake, and readable hover/roll labels. |
| P1 | Chance descriptions overpromise randomness | Existing ChancePayout and some RandomMultiplier behaviors use item-ID cadence, not random samples. Choose actual server RNG or honest periodic wording, then test preview/payout consistency; do not advertise probabilistic behavior without matching implementation. |
| P1 | Security and analytics evidence incomplete | Existing pure tests cannot prove every remote abuse path, engine session conflict, or Creator Dashboard event arrival. Complete deployed acceptance cases and capture results. |
| P2 | Documentation drift | This pass replaces old flat-odds/fixed-seller/twelve-machine/current-v2 claims, adds generated catalog, MVP completion phases and v2 gates. Keep evidence logs current as art and runtime work lands. |

## Requires Manual Validation

No new Studio/mobile/multiplayer test is claimed by this audit. Record device, date, build/commit, result, and issue for each test:

- Fresh account: understand roll → place → produce → sell → expand within one minute without explanation.
- Desktop and phone/tablet: complete loop, category placement, replace seller, inventory recycle, readable roll/hover/coin text, no obstructed touch targets.
- Rejoin after placement, replacement and inventory changes; forced disconnect; rapid session handoff; save failure path without wiping a valid factory.
- Two or more players: independent plots, wallets, machines, pickups, ownership validation and server caps.
- Slow seller and high-volume dropper: visible queue stays bounded, queued items eventually sell, no double payouts or stalls.
- Thirty-minute production soak with duplication and the maximum 24-item cap; profile client/server frame times and memory on target devices.
- Island models: anchoring, collision, camera, scale, spawn/navigation, first-load time, streaming, no falling parts or uncolored assets.
- Audio/visual readability, licensed asset permissions, and event arrival in Creator Dashboard.
- Successful main validation **and publish job**, then join a fresh published server showing v1.00.

## Finish order and release gate

Complete Phases 7–10 in `MVP-Completion-Plan.md`. v1.00 stays incomplete until those checklists and the manual acceptance log pass, and the owner approves the game's visual standard and playability. v2.00 is planned only; do not use graph features as a substitute for polishing the MVP.
