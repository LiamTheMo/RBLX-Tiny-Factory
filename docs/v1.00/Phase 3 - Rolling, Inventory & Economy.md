# Phase 3 — Rolling, Inventory & Economy

## Objective

Implement the acquisition and economy loop that gives players new factory choices while keeping machine ownership visible and server-authoritative.

## Player-facing result

- Machine rolls are free with a server-owned cooldown.
- Every rollable machine, including Seller, can be awarded to inventory.
- The Inventory button shows all owned machines and separates available copies from installed copies.
- Clicking a conveyor area opens a contextual machine picker with valid placement, replacement, move, and return actions.
- Players can recycle an available machine from the full inventory view.
- Coins earned from production and public pickups buy capacity upgrades.
- A cube earns Coins only when it reaches the Seller hitbox; the server settles its processed value with type, active sale-buff, and Seller modifiers.

## Systems

- Weighted, server-only machine rolls.
- Shared machine definitions and rarity display configuration.
- One durable inventory model used by both the inventory view and placement picker.
- Recycling for available machine copies.
- Capacity upgrades and temporary boosters.

## Technical work

- Configurable cooldown, inventory limit, weights, booster effects, and capacity prices.
- Atomic server-owned roll, placement, move, return, and recycle flow.
- Inventory quantities keyed by machine ID when instances are equivalent.
- Rarity, odds, names, and descriptions derived from shared machine definitions.
- UI list rows generated from machine definitions to keep future content modular.

## Gameplay work

- Start with a Common–Legendary rarity framework.
- Enable duplicate machines.
- Keep exactly one Seller as the last occupied point in the logical route. A rolled Seller replaces the prior terminal Seller through the same validated placement transaction.
- Recycle unwanted available machines without a Coin payout.
- Add a few meaningful capacity purchases beyond starting capacity.

## UI and UX work

- Bottom-center roll button and cooldown.
- Single roll reveal that shows machine name and odds on one line, with rarity shown by color and the final heading.
- Persistent Inventory button and complete owned-machine view.
- Contextual inventory view opened from the selected physical area.
- Clear available, placed, rarity, and recycle information.
- Compact capacity upgrade and Coin feedback.

## Security and performance

- Never accept a client-selected roll result.
- Validate cooldown, inventory space, machine ownership, and route legality before mutation.
- Prevent negative inventory and duplicate/replayed sell or upgrade requests.
- Keep launch inventory readable without virtualization; introduce it only if content growth requires it.
- Keep effects cosmetic and avoid per-item roll replication.

## Validation

Automated validation covers weighted odds, distinct roll weights, rarity mapping, inventory conservation, Seller rollability, capacity limits, and invalid economy requests.

Studio validation checks roll pacing, inventory comprehension, clicked-area placement, Seller movement, recycling, capacity purchase clarity, and mobile usability.

## Scope boundary

This phase does not add a second roll currency, player marketplace, paid luck, prestige, or a pity system.
