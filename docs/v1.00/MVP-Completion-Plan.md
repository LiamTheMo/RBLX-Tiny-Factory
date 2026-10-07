# v1.00 MVP Completion Plan

Status: **Incomplete / Needs Work**. Phases 1–6 supply a working foundation, not a finished product. These completion phases are required before v2.00. Implement each on a new minor branch from current v1.00; validate, review, merge to v1.00, validate there, then integrate/deploy through main.

## Phase 7 — Island World and Asset Integration

- Assemble the cheerful low-poly water-island setting: six player islands, safe connecting/navigation areas, central three-tier rocky mesa and large centered treehouse, explorative caves with restrained crystals.
- Preserve the single-route factory and plot isolation; model/environment scope does not introduce multiple worlds or logistics graphs.
- Confirm stable map keys, Roblox asset permissions, anchored models, useful collision, readable scale, spawn placement and camera clearance.
- Reduce mesh/triangle counts and repeated decorative assemblies; budget first-load time, streaming and draw cost on phone/tablet.
- Exit: a deployed map walkthrough and multiplayer spawn/plot test pass, with screenshots and recorded device/profile evidence. Prototype baseplate is no longer the player's world.

## Phase 8 — Machine Modeling and Readable Production

- Art inventory covers the generated machine catalog and existing upgraders. Track ID, family, model key, art status, collision/scale checks, animation and acceptance evidence.
- Use reusable base meshes with distinct modifier-family details and increasing rarity complexity, rather than 80 unrelated expensive assemblies.
- Droppers: standard modern tycoon form with downward output; no hoppers. Sellers: open conveyor-fed intake/factory, with a clearly visible sell region.
- Preserve each machine's footprint, cube path and logical sale contracts; animate cosmetic parts without changing server authority.
- Add coherent type palettes and restrained water/fire/air/lightning/time/etc. cues. Common shapes remain clear; rare models feel special without hiding the belt.
- Exit: all rollable machine IDs have intentional visuals; family/category/rarity are distinguishable from the gameplay camera; maximum factory remains within measured performance budgets.

## Phase 9 — UI, Audio, Onboarding and Balance

- Make inventory stat summaries complete: type multiplier, base value, spawn interval, seller bonus conditions and sale interval; match actual behavior.
- Test inventory navigation for the larger catalog; add search/sort only where it solves observed friction.
- Polish mobile safe areas, roll overlay/text, contextual placement, selection/cancel, hover information and sale feedback.
- Add licensed activation/sale/roll/build sounds and subdued ambience with volume/mute controls; cap overlapping audio/effects.
- Resolve probability wording vs item-ID cadence for legacy chance behaviors.
- Playtest first minute and first ten minutes; tune drop values/intervals, seller throughput, roll weights, capacity costs and booster pacing together. Record dominant and useful low-rarity combinations.
- Exit: new players understand the loop without explanation, three viable factory styles exist, mobile readability passes, and no presentation/stat claim contradicts implementation.

## Phase 10 — Playable MVP Acceptance and Release

- Run every automated suite, asset checks, compilation and Rojo build; review changed code and all available review findings.
- Complete the manual cases in `MVP-Audit.md`, including save/rejoin/session conflict, multiplayer, abuse attempts and a thirty-minute maximum-load soak.
- Record real profile measurements rather than assuming a target frame rate from code checks. Fix runtime issues using new minor branches.
- Maintain an acceptance log with device, build/commit, result and issue link; no unchecked test may be called passed.
- Validate major branch, merge to main, confirm main publish success and join a fresh deployed server.
- Exit: owner accepts visuals and playability; no unresolved P0/P1 MVP blocker; saves reliable; core loop usable on desktop/mobile; stable deployed build and evidence log.

## Gate to v2.00

Only begin the v2 implementation after Phase 10 acceptance. Existing historical v2.00 history stays intact. When v2 work begins, integrate the accepted v1 baseline into it through a minor branch and reviewed PR, preserving schema migrations and machine IDs.
