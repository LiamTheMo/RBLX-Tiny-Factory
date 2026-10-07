# Phase 2 — Branching, Splitters & Mergers

## Implementation gate

Status: **Planned — blocked on v1.00 MVP acceptance**. Complete v1 Phases 7–10, verify deployment and get owner approval of visuals/playability before implementing this phase. Preserve the existing historical v2.00 branch; integrate the accepted v1 baseline without rewriting history. Existing nested RNG, themed cubes, category inventory and alternate sellers are v1 foundations, not evidence that this phase is complete.

## Objective
Expose the first genuinely new logistics choices: branch flow, duplication/splitting rules, and convergence.

## Player-Facing Result
- Players can route production into multiple paths and recombine flows.

## Systems
- Splitter node
- Merger node
- branch policy
- congestion/capacity behavior

## Technical Work
- Define deterministic split policy.
- Define merge queue behavior.
- Prevent duplicate accounting.
- Add per-route backpressure rules if needed.

## Gameplay Work
- Add limited modular conveyor pieces.
- Create at least two strategy patterns that benefit from branching.
- Keep sorter logic simple or defer it.

## UI/UX Work
- Connection preview
- direction arrows
- branch configuration only if absolutely necessary
- invalid-network feedback

## Art / Audio / Asset Requirements
- Splitter/merger models
- clear lane arrows
- branch flow effects

## Dependencies
v2 Phase 1 graph foundation.

## Analytics / Instrumentation
- splitter/merger placement
- route counts
- branch utilization
- congestion
- abandoned branches

## Security / Exploit Considerations
- Validate connection ownership and output count.
- Ensure split logic cannot duplicate value outside intended mechanics.

## Performance Considerations
- Branch fanout cap.
- Per-route item cap.
- Profile merger queues.

## Automated Validation
- Split/merge conservation tests
- congestion tests
- graph edit tests during active production

## Manual Validation
- Readability of branch direction
- mobile connection editing
- visual tracking of items through split/merge

## Scope Classification
### Required Now
- splitters
- mergers
- branch readability
### Valuable Later
- advanced sorters
- conditional routing
### Scope Creep
- programmable routing

## Explicitly Out of Scope
- automation scripting
- blueprint sharing

## Completion Definition
Complete when players can create, understand, save, reload, and optimize branched lines without item/value duplication bugs.
