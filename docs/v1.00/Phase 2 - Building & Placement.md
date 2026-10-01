# Phase 2 — Building & Placement

## Objective

Let players place and rearrange owned machines on one compact, left-to-right proof-of-concept conveyor. The server remains authoritative for ownership, capacity, route validity, and simulation order.

## Player-facing result

- The temporary conveyor has five clickable factory areas.
- Clicking any area opens a contextual view of owned machines that can be placed there, plus valid move and return actions.
- A persistent Inventory button opens a complete ownership list. Counts include machines that are available and machines already installed.
- Players can roll a Seller. It can occupy any valid route end instead of being fixed to the fifth area.
- A temporary dropper assembly visibly releases cubes onto the conveyor.
- The route still begins with one dropper and ends with one Seller. Empty physical areas are skipped by the simulation.

## Route and capacity rules

- Area 1 must contain exactly one producer/dropper.
- Processor machines can be placed only in unlocked areas.
- Exactly one Seller must be the last occupied area. The Seller is terminal, but its physical area can change.
- A rolled Seller replaces the existing terminal Seller in one validated operation; it cannot create a second Seller.
- The Seller does not consume a processor capacity slot.
- Moves and placements are transactional. A failed request leaves both the route and inventory unchanged.
- The machine order in physical areas is the processing order.

## Systems

- Five-area physical layout backed by a compact ordered logical route.
- Shared, pure placement rules for previewing and server validation.
- Server-authoritative placement, replacement, movement, return, and inventory updates.
- Click-to-open placement UI and full inventory view.
- Temporary machine visuals and a visible first dropper item.
- Save-compatible layout state.

## UI and content modularity

Machine names, categories, rarity colors, roll weights, and display descriptions come from shared definitions/configuration. The inventory list derives its rows from machine definitions and current owned counts, so adding a machine does not require a copied client-side list. Visual families use data-driven MachineVisualConfig profiles. New machine families can add a profile and select it from a machine definition.

## Validation

Automated tests cover all five clickable areas, producer and Seller constraints, Seller rollability and movement, processor capacity, invalid route ordering, removal, and invalid indices.

Studio acceptance checks:

- Click empty and occupied areas, including the current Seller area.
- Place, replace, move, and return a processor from the contextual inventory.
- Move a rolled Seller to another route end and confirm the old Seller becomes available inventory.
- Open the Inventory button and compare owned, placed, and available counts.
- Confirm no unrelated player's plot responds to the click.
- Verify a cube visibly falls from the placeholder Dropper and travels along the conveyor on desktop and touch devices.

## Scope boundary

This is a temporary single-route proof of concept. It does not add a modular belt graph, splitters, mergers, free-form machine placement, or production physics. The placeholder models and click panel can be replaced later without changing the shared machine definitions or server placement rules.
