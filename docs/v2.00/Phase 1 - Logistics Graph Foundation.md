# Phase 1 — Logistics Graph Foundation

## Implementation gate

Status: **Planned — blocked on v1.00 MVP acceptance**. Complete v1 Phases 7–10, verify deployment and get owner approval of visuals/playability before implementing this phase. Preserve the existing historical v2.00 branch; integrate the accepted v1 baseline without rewriting history. Existing nested RNG, themed cubes, category inventory and alternate sellers are v1 foundations, not evidence that this phase is complete.

## Objective
Replace the single-route assumption with a maintainable representation that can support multiple connected paths.

## Player-Facing Result
- Early internal builds can support more than one route and directional conveyor connectivity.

## Systems
- Logistics graph/nodes
- Connection validation
- Route scheduling
- Layout schema v2

## Technical Work
- Introduce node IDs and directional connections.
- Migrate v1 linear layouts into valid v2 graphs.
- Separate topology from visuals.
- Add graph validation and cycle policy.

## Gameplay Work
- Keep the player-facing conveyor set minimal while the topology is stabilized.

## UI/UX Work
- Debug topology visualization first; final building UI comes later.

## Art / Audio / Asset Requirements
- Placeholder conveyor junctions and connection arrows.

## Dependencies
Validated v1 loop and migration framework.

## Analytics / Instrumentation
- Graph size
- node count
- invalid connection reasons
- simulation cost by graph complexity

## Security / Exploit Considerations
- Server validates every edge and node ownership.
- Reject malformed/cyclic layouts according to policy.

## Performance Considerations
- Avoid traversing whole graph every frame.
- Cache routes/adjacency.
- Bound node/edge counts.

## Automated Validation
- Graph validity tests
- v1→v2 migration tests
- deterministic routing tests
- cycle/invalid-edge tests

## Manual Validation
- Multiple routes run correctly.
- Layout changes do not orphan items.
- Migration preserves existing factories.

## Scope Classification
### Required Now
- topology model
- migration
- deterministic routing
### Valuable Later
- advanced sorter rules
- blueprints
### Scope Creep
- scripting language
- unlimited graph size

## Explicitly Out of Scope
- social progression
- events
- trading

## Completion Definition
Complete when v1 layouts migrate safely and the simulation can deterministically run bounded multi-route factory graphs.
