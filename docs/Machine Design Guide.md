# Machine Design Guide

## 1. Purpose

Every new machine must create a reason to think about the factory.

A machine is not justified merely because it can have a larger multiplier.

## 2. Core Design Test

Before adding a machine, answer:

1. What decision does this machine create?
2. Does placement order matter?
3. Does it enable a strategy that existing machines do not?
4. Can the effect be understood by watching the item?
5. Does it remain computationally cheap enough?
6. Can it be expressed using an existing behavior module?
7. Does it invalidate another machine?
8. Is the rarity based on interestingness/scarcity rather than raw power alone?

If the answers are weak, do not add it.

## 3. Machine Categories

- **Producer** — creates items.
- **Value Modifier** — directly changes value.
- **Physical Modifier** — changes visible item state.
- **Throughput** — changes speed/capacity/timing.
- **Duplicator/Splitter** — changes item count or path.
- **Combiner/Merger** — combines streams or states.
- **Converter** — changes one property into another.
- **Random/Risk** — adds bounded uncertainty.
- **Seller** — converts production into currency.
- **Utility** — solves layout/control problems.

v1.00 should use only a subset.

## 4. Readability Rule

A player should be able to infer the broad effect from:

- machine silhouette
- animation
- color/material language
- item transformation
- concise tooltip

If a machine needs multiple paragraphs to understand, it is probably too complicated for early versions.

## 5. Synergy Design

Good synergy:

- creates tradeoffs
- depends on order
- uses visible item state
- supports multiple viable chains
- has understandable constraints

Weak synergy:

- hidden global multiplier
- arbitrary “+10% if machine X exists”
- requires memorizing invisible exceptions
- only matters at extreme endgame

## 6. Power Budgeting

Machine power should consider:

- value increase
- throughput change
- item count increase
- footprint / slot cost
- processing delay
- prerequisites
- randomness
- downstream congestion
- opportunity cost

A Duplicator can be powerful because it also doubles downstream load.

A high multiplier may be balanced by slow processing or narrow compatibility.

## 7. Rarity Philosophy

Rarity may represent:

- acquisition chance
- unusual behavior
- specialization
- flexibility
- power ceiling

Rarity must not guarantee that the machine is better in every build.

Aim for situations where:

- a Common speed tool remains useful
- an Uncommon converter enables a niche chain
- a Legendary machine is exciting but not mandatory

## 8. Input / Output Contract

Every machine should define:

- valid input
- processing effect
- processing time
- output count
- output state
- failure/skip behavior
- cap behavior where relevant

Avoid ambiguous “sometimes works” behavior unless randomness is the point.

## 9. Visual Feedback

Prefer one strong readable effect:

- stamp
- squeeze
- split
- recolor
- pulse
- size change
- rotate/reshape
- teleport

Do not stack excessive particles.

## 10. Performance Budget

Avoid machines that:

- spawn uncontrolled item cascades
- create nested physics assemblies
- require per-frame server raycasts
- scan the full factory repeatedly
- store huge transformation histories
- replicate unnecessary state every frame

Duplication mechanics must enforce item caps and downstream capacity.

## 11. Complexity Threshold

A machine is too complicated when it requires:

- a dedicated UI panel for normal use
- many unique exceptions
- multiple currencies
- per-instance persistent state with little payoff
- a new subsystem that only one machine uses

Consider merging several ideas into one modular machine if they differ only by parameters.

## 12. Modular Machine Rule

If three proposed machines are:

- ×2 Stamper
- ×3 Stamper
- ×4 Stamper

they may belong to one `MultiplyValue` behavior with rarity/config variants.

If three proposed machines instead change:

- size
- material
- duplication

they likely deserve distinct behaviors because they create different strategies.

## 13. v1.00 Machine Cap

The user-approved MVP target is 5–15 droppers and 5–15 sellers in each rarity; the implemented target is eight of each. Existing upgraders remain. Reuse behavior and visual families; do not mistake parameter variants for new systems. Every machine increases:

- balance combinations
- UI load
- testing burden
- analytics complexity
- art/audio work
- player comprehension cost

## 14. Machine Acceptance Checklist

A machine is ready when:

- effect is readable
- server implementation is deterministic enough
- exploit cases are handled
- performance cost is bounded
- interactions with existing launch machines are tested
- tooltip matches actual behavior
- analytics ID exists
- rarity/pool placement is justified
