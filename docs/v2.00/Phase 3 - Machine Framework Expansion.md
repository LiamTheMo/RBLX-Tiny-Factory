# Phase 3 — Machine Framework Expansion

## Implementation gate

Status: **Planned — blocked on v1.00 MVP acceptance**. Complete v1 Phases 7–10, verify deployment and get owner approval of visuals/playability before implementing this phase. Preserve the existing historical v2.00 branch; integrate the accepted v1 baseline without rewriting history. Existing nested RNG, themed cubes, category inventory and alternate sellers are v1 foundations, not evidence that this phase is complete.

## Objective
Scale content without scaling code complexity at the same rate.

## Player-Facing Result
- A larger machine pool supports distinct factory strategies and new branch interactions.

## Systems
- Behavior composition
- richer tags
- compatibility rules
- machine definition schema v2
- content validator

## Technical Work
- Refactor repeated bespoke logic into reusable behaviors.
- Add definition validation.
- Support richer input/output constraints.
- Add per-machine processing cost metrics.

## Gameplay Work
- Build on the accepted MVP catalog; add converters/sorters only when graph interactions justify them.
- Add converters, sorters, conditional/risk machines selectively.
- Preserve usefulness of earlier machines.

## UI/UX Work
- Better tooltips for compatibility and throughput.
- Category filtering if inventory size now requires it.

## Art / Audio / Asset Requirements
- New machine models/effects prioritized by mechanical readability.

## Dependencies
Stable branched logistics.

## Analytics / Instrumentation
- content usage
- pair/order frequency
- branch-specific machine usage
- dead content
- dominant combinations

## Security / Exploit Considerations
- Server validates all behavior parameters from trusted definitions.
- Bound random/output-heavy mechanics.

## Performance Considerations
- Budget each machine behavior.
- Profile worst-case stacked chains.
- No unbounded scans.

## Automated Validation
- Definition schema tests
- behavior-module tests
- representative interaction matrix
- production upper-bound simulations

## Current roll and cube catalog contract

The machine roll is a server-owned nested weighted draw:

1. `EconomyConfig.RarityWeights` selects a rarity.
2. Only rollable machines in that rarity are eligible; their `RollWeight`
   values select the machine.

The exact whole-roll chance is the rarity chance multiplied by the machine's
share of its rarity's inner weight. The server returns those computed odds for
the inventory and roll result UI. Do not treat the inner weight as an additional
rarity or run the two selections from the client.

`CubeTypeDefinitions` is the source of truth for cube names, type rarity,
display color, and base value multiplier. It currently defines Standard, Wet,
Air, Nature, Earth, Fire, Ice, Metal, Lightning, Light, Shadow, Time, Crystal,
and Rainbow cubes. Producer spawn intervals and base values, type-filtered
upgrader multipliers, and seller payout rules live in `MachineDefinitions`.
The simulation applies cube type value first, then matching route upgraders,
then the terminal seller's rule. Monetary payouts retain two decimal places.

The catalog includes rollable producers, upgraders, and alternate sellers.
Inventory is grouped by category; alternate sellers are only valid in the
terminal seller slot. Machine odds and all money changes are calculated by the
server. Treat the supplied numbers as first-pass balance values for playtesting.

## Manual Validation
- Strategy diversity
- readability of new machines
- low-rarity relevance
- no universally optimal chain

## Scope Classification
### Required Now
- reusable content framework
- meaningful new machine categories
### Valuable Later
- machine skins
- special event variants
### Scope Creep
- hundreds of machines
- per-machine unique subsystem

## Explicitly Out of Scope
- live-service content tooling beyond basic validators

## Completion Definition
Complete when adding a standard new machine is mostly configuration + reusable behavior, and the expanded pool demonstrably creates distinct strategies.
