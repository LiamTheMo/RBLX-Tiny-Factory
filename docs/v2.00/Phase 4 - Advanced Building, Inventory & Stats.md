# Phase 4 — Advanced Building, Inventory & Stats

## Implementation gate

Status: **Planned — blocked on v1.00 MVP acceptance**. Complete v1 Phases 7–10, verify deployment and get owner approval of visuals/playability before implementing this phase. Preserve the existing historical v2.00 branch; integrate the accepted v1 baseline without rewriting history. Existing nested RNG, themed cubes, category inventory and alternate sellers are v1 foundations, not evidence that this phase is complete.

## Objective
Make larger factories manageable without turning building into an engineering tool.

## Player-Facing Result
- Players can edit larger layouts quickly, understand bottlenecks, and find machines in a larger inventory.

## Systems
- Improved build tools
- inventory search/filter/sort if needed
- production statistics
- bottleneck indicators

## Technical Work
- Add safe batch move/copy only if it materially improves use.
- Add aggregated production stats.
- Optimize layout serialization and diff updates.

## Gameplay Work
- Surface throughput/value tradeoffs without auto-solving layouts.

## UI/UX Work
- Search/filter
- category tabs
- production/minute
- route/item count
- optional bottleneck hints
- improved mobile build controls

## Art / Audio / Asset Requirements
- Simple stat icons
- route highlights
- congestion indicator

## Dependencies
Expanded v2 machine/logistics complexity.

## Analytics / Instrumentation
- build-tool usage
- time to complete edits
- inventory search/filter usage
- bottleneck prevalence

## Security / Exploit Considerations
- Batch operations remain atomic and ownership-validated.
- Stats are derived server-side or from trusted replicated summaries.

## Performance Considerations
- Throttle stat updates.
- Avoid recomputing full graph every UI frame.

## Automated Validation
- Batch edit tests
- filter/search config tests
- stats calculation tests
- layout diff tests

## Manual Validation
- Can players manage near-cap factories?
- Mobile edit time
- Do stats help without dictating one solution?

## Scope Classification
### Required Now
- manageable building
- useful production stats
### Valuable Later
- blueprints
- saved loadouts
### Scope Creep
- CAD-like editor
- auto-optimizer

## Explicitly Out of Scope
- social sharing of layouts

## Completion Definition
Complete when v2-scale factories remain quick to edit and players can diagnose basic throughput problems without excessive UI complexity.
