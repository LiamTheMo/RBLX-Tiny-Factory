# Phase 4 — Launch Machine Set & Synergies

## Objective
Build the approved catalog with reusable behaviors and intentional visuals that prove ordering, throughput, and combination decisions are fun.

## Player-Facing Result
- Players can create visibly different chains and discover that machine order matters.
- Rare machines are exciting without replacing every common option.

## Systems
- Reusable machine behavior modules
- Launch machine definitions
- Compatibility/tag rules
- Visual state updates

## Technical Work
- Implement common behavior modules such as MultiplyValue, ScaleVisual, SetMaterial, DuplicateItem, RandomMultiplier, AdjustThroughput.
- Keep bespoke behavior isolated.
- Add bounded duplicate/output logic.

## Gameplay Work
- Use eight droppers and eight sellers per rarity, plus existing upgraders; see `Machine-Catalog.md`.
- Ensure at least 3 meaningful strategy patterns.
- Design at least several order-sensitive interactions.
- Roll alternate sellers and replace the dedicated terminal bay transactionally; enforce payout conditions and sale intervals.

## UI/UX Work
- Clear one-line machine effects
- Processing/cooldown values only where useful
- Compatibility warning
- Production feedback/popups

## Art / Audio / Asset Requirements
- Distinct silhouettes for launch machines
- Strong readable machine animation
- Transformation effects
- Machine-specific activation sounds where worthwhile

## Dependencies
Phases 1–3.

## Analytics / Instrumentation
- Machine usage rate
- Machine order pairs
- Machines rolled but never placed
- Replacements by rarity
- Synergy/layout change signals

## Security / Exploit Considerations
- Duplicator/output machines obey caps.
- Random machine effects use server RNG.
- All value changes bounded/sanitized.

## Performance Considerations
- Profile worst-case chain.
- Pool visual items/effects where useful.
- Avoid cascading unbounded duplication.

## Automated Validation
- Definition schema validation
- Pairwise machine processing tests for core combinations
- Upper-bound production tests
- No-invalid-number tests

## Manual Validation
- Can testers explain what each machine did by watching?
- Do testers voluntarily reorder?
- Is any machine always correct?
- Does rarity feel exciting but not mandatory?
- Are effects readable on mobile?

## Scope Classification
### Required Now
- varied catalog built from bounded reusable behaviors
- readable effects
- order-sensitive interactions
- multiple viable strategies
### Valuable Later
- more categories
- converters
- sorters
- deeper tags
### Scope Creep
- unique expensive subsystems per content variant
- affixes
- machine leveling
- fusion

## Explicitly Out of Scope
- v2 logistics nodes
- research
- prestige
- seasonal pools

## Completion Definition
Phase is complete when the launch set creates repeated voluntary layout experimentation, every machine is readable, and automated interaction tests show no obvious broken combination.
