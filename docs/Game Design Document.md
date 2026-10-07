# Game Design Document

## 1. Product Identity

Tiny Factory is a compact, playful, readable factory-incremental game. Players roll for machines and arrange them into visible production chains.

The game's strongest possible player story is:

> “I rolled something weird, rebuilt my line around it, and discovered a much better setup.”

The game should reward experimentation more than passive waiting.

## 2. Design Status Legend

- **Current Design** — intended for v1.00 unless removed by testing.
- **Planned Design** — intended for a later validated version.
- **Speculative** — possible future direction; not approved scope.

## 3. Core Loop — Current Design

Produce → transform → sell → earn → roll → decide → rebuild → expand → repeat. Rolls are free on a server cooldown; Coins pay for capacity.

The loop succeeds when players repeatedly make **layout decisions**, not merely wait for an upgrade button.

## 4. Factory Building — Current Design

v1.00 uses a deliberately constrained building model:

- one player plot
- one logical production route
- fixed or semi-fixed conveyor backbone
- machine slots on a grid
- place / move / rotate / remove
- short interaction distances and obvious snapping
- no unrestricted Factorio-style conveyor graph

The recommended v1.00 implementation is a **fixed-path slot system** or **grid slots along a predefined route**. It is faster to build, easier to save, easier to use on mobile, and still proves whether machine ordering is fun.

### Planned

v2.00 may introduce:

- modular conveyor pieces
- branches
- splitters
- mergers
- sorters
- multiple lines
- copy/move tools

Only after v1.00 proves that players care about rebuilding.

## 5. Item Production — Current Design

A production item should contain only gameplay-relevant state:

- item archetype / shape
- base value
- current value
- visual material/color state
- size scalar if required
- compact modifier flags/tags when necessary
- source producer ID for analytics

Do not persist transient conveyor items.

Items visually travel through the factory. Simulation should not depend on unrestricted Roblox physics.

## 6. Conveyors — Current Design

Conveyors primarily communicate item motion.

Recommended implementation:

- deterministic path movement
- anchored or non-colliding visual items
- server-authoritative logical progress
- client-supported interpolation/effects where safe
- hard cap on active items per factory

The conveyor is not a physics sandbox.

## 7. Machine Interactions — Current Design

Each processor should create a visible, understandable change.

Initial machine categories should focus on a few distinct decisions:

- producers
- direct value modifiers
- physical/visual modifiers
- one duplication-style mechanic
- one risk/randomness mechanic
- utility/speed
- seller

Machine order should matter where it creates understandable strategy.

Example:

- Giantifier before a size-sensitive multiplier can be stronger than the reverse.
- A Duplicator placed before an expensive transformation creates additional processing demand.
- A speed booster can improve throughput only when downstream machines can keep up.

Avoid opaque interactions that require a wiki during the first release.

## 8. RNG — Current Design

RNG determines which machine option appears, but the player should keep agency.

v1.00 recommended model:

- Rolls are free with a server-authoritative cooldown.
- A roll returns one machine or, if implementation cost remains low, a **choice of three**.
- Duplicate machines are allowed.
- Unwanted machines can be recycled without a Coin payout.
- A lightweight pity or bad-luck protection system may exist if test data shows streak frustration.

Do not sell real-money luck or rare rolls in v1.00.

## 9. Rarity — Current Design

Initial rarity ladder:

- Common
- Uncommon
- Rare
- Epic
- Legendary

Rarity communicates acquisition frequency and mechanical unusualness, not guaranteed universal superiority.

A low-rarity machine can remain useful because of:

- low processing delay
- specific tags
- synergy
- compact footprint
- predictable behavior
- favorable throughput

## 10. Initial Machine Set — Current Design

The MVP catalog contains eight rollable droppers and eight rollable sellers per supported rarity (80 combined), plus the existing upgrader set. This supersedes the initial twelve-machine target. Shared behavior and art families keep variants manageable; balance and visual readiness are still acceptance requirements. See `v1.00/Machine-Catalog.md`.

The following list describes the original behavior foundation, not the complete current pool:

Suggested launch set:

### Producers
1. Basic Dropper
2. Fast Dropper
3. Heavy Dropper

### Core Modifiers
4. Value Stamper
5. Giantifier
6. Paint Machine
7. Compound Press

### Utility / Flow
8. Conveyor Booster
9. Cooldown Tuner

### Special
10. Duplicator
11. Goldenizer
12. Lucky Modifier

### Seller
Sellers are rolled machines. Exactly one occupies the dedicated terminal bay; replacements conserve ownership. Each seller has a payout rule and a server-enforced sale interval.

This list is a design starting point, not a promise. Remove any machine that does not create a meaningful choice.

## 11. Progression — Current Design

v1.00 progression consists of:

- Coins
- bounded machine inventory growth
- a small number of factory capacity upgrades
- production milestones
- discovery of machine types

No prestige is required.

### Planned

v3.00 may add:

- collection completion
- research
- factory tiers
- challenge tracks
- persistent specialization
- conditional prestige if reset-based play has a clear strategic purpose

## 12. Economy — Current Design

Use **Coins only** in v1.00.

Coins pay for:

- limited factory capacity upgrades

Unwanted machines can be recycled to free inventory space. Free rolls cannot generate Coins through recycling.

The economy must keep players rebuilding rather than waiting for exponential passive accumulation.

## 13. Factory Expansion — Current Design

Use a few capacity steps, such as:

- initial slots
- one affordable early extension
- one mid-session extension
- one later-session extension

Expansion should increase design possibility, not simply floor size.

## 14. UX — Current Design

A new player should immediately understand:

- where items originate
- where they travel
- what machines do
- where value changes
- where items are sold
- current Coins
- how to roll
- how to place a machine

Machine cards/tooltips should show:

- name
- rarity
- category
- one-sentence effect
- key number(s)
- basic compatibility warning if relevant

Avoid giant stat sheets.

## 15. Visual Direction — Current Design

Style:

- compact
- toy-like
- colorful
- chunky
- mechanical
- readable
- slightly chaotic

Examples of visual communication:

- Duplicator physically splits an item
- Goldenizer recolors it with a metallic flash
- Giantifier enlarges it
- Value Stamper visibly stamps a number/icon
- Seller pulls the item in and emits a Coin burst

Effects should reinforce state changes without obscuring the line.

## 16. Audio — Current Design

Use short, layered feedback:

- drop sound
- conveyor hum
- machine activation
- transformation accent
- rare-machine roll stinger
- sale/coin confirmation
- placement/move sounds

Avoid constant overlapping noise from every machine.

## 17. Mobile — Current Design

v1.00 must support mobile building.

Requirements:

- large machine selection cards
- placement preview
- obvious valid/invalid state
- tap to select
- drag or guided slot selection
- rotate button rather than precision gesture dependence
- easy cancel
- no tiny hit targets

## 18. Multiplayer — Current Design

Players may share a server, but each factory remains independently functional.

v1.00 does not require:

- cooperation
- trading
- shared production
- competition

Other players can be visible without becoming a dependency.

## 19. Monetization Principles — Current Design

Do not monetize the validation question.

Avoid in v1.00:

- paid luck
- premium-only machines
- direct production multipliers
- paid reroll pressure
- gambling-like machine purchase loops

### Planned / Conditional

Safer future options:

- factory themes
- machine skins
- conveyor skins
- decorative props
- cosmetic item trails
- UI themes
- supporter cosmetics

## 20. Long-Term Possibilities — Speculative

Only if earlier versions validate:

- multiple factory worlds
- player blueprint sharing
- co-op mega-factories
- seasonal machine sets
- server production goals
- advanced research
- sophisticated automation
- trading/marketplace
- clan factories

None are current commitments.

## 21. Design Kill Tests

A proposed feature should be rejected or deferred if:

- it works without interacting with the factory
- it makes layout order less meaningful
- it adds a currency without a unique economic purpose
- it invalidates most existing machines
- it requires excessive UI management
- it causes major performance cost for minor gameplay value
- it makes spending more important than factory decisions
- it primarily imitates generic Roblox simulator conventions
