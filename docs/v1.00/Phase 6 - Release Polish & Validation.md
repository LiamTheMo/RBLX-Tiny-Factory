# Phase 6 — Release Polish & Validation

## Objective
Polish only what is necessary to make the core loop understandable, satisfying, measurable, and public-test ready.

## Implementation Status
The release pass now includes a production-named HUD, build-version labeling, first-minute onboarding cues driven by real roll/place/sell events, mobile-sized touch controls, bounded machine visuals, and CI coverage for every cumulative v0 checkpoint. Roblox Studio launch, reconnect, multiplayer, and device profiling remain manual acceptance checks.

## Player-Facing Result
- First minute is clear.
- Machine interactions feel satisfying.
- Mobile and desktop controls are usable.
- The game has enough presentation quality for honest retention testing.

## Systems
- Onboarding cues
- Feedback polish
- Settings essentials
- launch configuration
- test/rollback checklist

## Technical Work
- Remove debug-only code/UI.
- Verify production configs.
- Confirm analytics build labels.
- Run profiling and exploit regression suite.
- Prepare safe data defaults.

## Gameplay Work
- Tune first roll timing.
- Tune roll/expansion tension.
- Remove weak machines if necessary.
- Ensure first session exposes several meaningful decisions quickly.

## UI/UX Work
- Minimal onboarding prompts instead of long tutorial.
- Final HUD hierarchy.
- Mobile safe areas/touch sizes.
- Clear build/roll/inventory navigation.

## Art / Audio / Asset Requirements
- Final-enough launch machine visuals
- Core SFX
- Limited particles
- Simple environment dressing
- Basic icon/thumbnail if release requires it

## Dependencies
All previous v1 phases.

## Analytics / Instrumentation
- Confirm all key funnel events.
- Add build/version tag.
- Prepare launch review queries/dashboard.

## Security / Exploit Considerations
- Final remote audit.
- Attempt currency/roll/placement abuse.
- Check accidental debug/admin exposure.

## Performance Considerations
- Test maximum v1 slot/item configuration.
- Test several players per server.
- Device/mobile profiling.
- Cap expensive effects.

## Automated Validation
- Full CI
- tests/lint/format/type checks
- definition validator
- save migration suite
- economy invariants
- static remote audit where available

## Manual Validation
- New-player no-explanation test
- mobile full loop
- desktop full loop
- reconnect
- multiplayer
- prolonged idle production
- worst-case machine chain
- audio/visual readability

## Scope Classification
### Required Now
- comprehension
- stability
- satisfying feedback
- launch analytics
### Valuable Later
- elaborate tutorial
- cosmetic shop
- more content
### Scope Creep
- adding v2 features to improve launch optics
- last-minute currencies
- social hub

## Explicitly Out of Scope
- Any feature not required to answer the v1 validation question.

## Completion Definition
Phase 1–6 automated checks prove the foundation only. v1.00 remains incomplete until Phases 7–10 in `MVP-Completion-Plan.md` deliver the modeled world, intentional machine art, UI/audio/balance polish, and deployed manual acceptance. Owner approval of visual quality and playability is required before starting v2.00.
