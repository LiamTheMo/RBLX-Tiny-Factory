# Phase 5 — Balance, Performance & v2 Validation

## Implementation gate

Status: **Planned — blocked on v1.00 MVP acceptance**. Complete v1 Phases 7–10, verify deployment and get owner approval of visuals/playability before implementing this phase. Preserve the existing historical v2.00 branch; integrate the accepted v1 baseline without rewriting history. Existing nested RNG, themed cubes, category inventory and alternate sellers are v1 foundations, not evidence that this phase is complete.

## Objective
Prove that added complexity creates meaningful diversity rather than confusion, dominance, or performance collapse.

## Player-Facing Result
- Multiple factory styles are viable and understandable at the intended v2 scale.

## Systems
- Balance configs
- profiling
- strategy telemetry
- migration hardening

## Technical Work
- Profile worst-case graphs.
- Optimize hotspots.
- Validate old saves.
- Add stronger simulation diagnostics.

## Gameplay Work
- Nerf/buff only from observed evidence.
- Remove or simplify machines/logistics that add complexity without decisions.

## UI/UX Work
- Polish branch readability and stat hierarchy.

## Art / Audio / Asset Requirements
- Finalize only the content retained after testing.

## Dependencies
All v2 phases.

## Analytics / Instrumentation
- layout diversity
- strategy concentration
- branch adoption
- rebuild frequency
- performance percentiles

## Security / Exploit Considerations
- Regression audit on richer placement and machine graph.

## Performance Considerations
- Stress intended maximum graph/item caps across multiple players.

## Automated Validation
- full CI
- graph/migration regression
- content validator
- production simulation suite
- economy invariants

## Manual Validation
- new/returning player comprehension
- mobile
- multiplayer
- worst-case factories
- long sessions
- save migrations

## Scope Classification
### Required Now
- diversity
- stability
- maintainable content pipeline
### Valuable Later
- progression/social expansion
### Scope Creep
- beginning v3 before v2 data is understood

## Explicitly Out of Scope
- research, showcases, leaderboards unless used only in internal prototypes

## Completion Definition
v2.00 exits when richer factories remain understandable, multiple strategies appear in real usage, content additions are maintainable, and technical limits hold under stress.
