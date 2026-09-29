# Phase 3 — Rolling, Inventory & Economy

## Objective
Implement the acquisition/economy loop that turns production into new factory choices.

## Player-Facing Result
- Machine rolls are free with a server-owned cooldown.
- Rolled machines enter inventory.
- Players can place, store, or recycle machines.
- Coins earned from production and pickups buy capacity upgrades.

## Systems
- RollService
- InventoryService
- EconomyService
- Rarity tables
- Recycling
- Capacity upgrades

## Technical Work
- Server-only weighted RNG.
- Configurable cooldown, inventory limit, weights, and capacity prices.
- Atomic server-owned roll/grant flow.
- Inventory quantities by machine ID where instances are equivalent.
- Request rate limits/idempotency protection as needed.

## Gameplay Work
- Start with Common–Legendary rarity framework.
- Enable duplicate machines.
- Recycle unwanted machines without a Coin payout.
- Add 2–3 meaningful capacity purchases beyond starting capacity.

## UI/UX Work
- Bottom-center roll button and cooldown
- Roll result presentation
- Compact inventory
- Rarity/readable effect info
- Recycle confirmation
- Capacity upgrade display

## Art / Audio / Asset Requirements
- Rarity frames/icons
- Simple roll reveal
- Cooldown and Coin feedback
- Inventory machine thumbnails/placeholders

## Dependencies
Placement system and machine definitions from Phases 1–2.

## Analytics / Instrumentation
- Free roll granted
- Rarity result
- Machine granted
- Machine recycled
- Coins earned/spent on capacity
- Capacity purchased
- Time to first roll

## Security / Exploit Considerations
- Never accept client-selected roll result.
- Validate cooldown and inventory space before grant.
- Prevent negative inventory.
- Prevent replayed sell/upgrade requests.

## Performance Considerations
- Inventory UI virtualizes only if actually needed; launch inventory is small.
- Avoid excessive roll animation replication.

## Automated Validation
- Weighted table validation
- Transaction conservation tests
- Negative/overflow tests
- Inventory add/remove tests
- Capacity permission tests

## Manual Validation
- Roll pacing
- Inventory comprehension
- Cooldown and recycling frustration
- Capacity purchase clarity
- mobile inventory usability

## Scope Classification
### Required Now
- Coins
- rolls
- inventory
- recycling
- capacity
### Valuable Later
- choice-of-three
- rerolls
- pity system
- filters
### Scope Creep
- gems
- tickets
- paid luck
- trading

## Explicitly Out of Scope
- Prestige
- social economy
- multiple roll currencies
- player marketplace

## Completion Definition
Phase is complete when free rolls, inventory decisions, placement, recycling, and Coin-funded expansion work with no trivial exploit path.
