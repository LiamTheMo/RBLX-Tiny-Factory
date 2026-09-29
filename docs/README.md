# Tiny Factory

## Premise

**Tiny Factory** is a compact Roblox incremental/factory game about rolling for machines, placing them into a small production line, and discovering profitable combinations.

The central fantasy is:

> **I built this ridiculous production chain.**

The factory—not pets, rebirth pads, currencies, or giant menus—is the star.

## Core Loop

1. Produce items.
2. Process them through machines.
3. Sell them.
4. Earn Coins.
5. Roll for another machine for free after the server cooldown.
6. Decide whether to place, replace, store, or sell the result.
7. Rebuild the factory.
8. Increase production.
9. Unlock limited extra capacity.
10. Repeat.

A new player should see an item produced, visibly modified, sold, and converted into currency within the first minute.

## Project Purpose

Tiny Factory is intentionally a **validation-first** project. v1.00 exists to answer one question:

> **Do players enjoy rolling machines, rearranging their factory, and discovering profitable combinations?**

The project should not automatically grow because a roadmap exists. Every major expansion is conditional on the previous version proving that its core experience deserves more development.

## Development Philosophy

**Release → measure → learn → expand**

The first public build should be the smallest reliable implementation that proves the factory loop.

When tradeoffs occur, prioritize:

1. Factory loop
2. Machine interactions
3. Building usability
4. Visible production feedback
5. Economy clarity
6. Saving reliability
7. Performance
8. Mobile usability
9. Maintainability
10. Analytics
11. Content variety
12. Progression
13. Social systems
14. Monetization

## Major-Version Philosophy

Major versions represent new **system capacity**, not arbitrary feature batches.

- **v1.00 — Core Factory Validation**  
  Small, reliable factory simulation that proves the loop.

- **v2.00 — Factory Complexity & Content Scalability**  
  Multiple paths, deeper logistics, stronger machine interactions, and architecture that makes new content inexpensive to add.

- **v3.00 — Progression & Social Scalability**  
  Long-term goals, collections, research, showcases, records, and carefully selected social systems.

- **v4.00 — Live Service & Content Pipeline Scalability**  
  Data-driven content, tooling, migration safety, feature flags, observability, and sustainable solo operation.

- **Future — Only if validated**  
  Worlds, mega-factories, blueprint sharing, cooperative goals, advanced prestige, market systems, and similar ideas remain conceptual.

## Solo-Developer Constraint

Every feature is judged by:

- implementation time
- maintenance cost
- balancing cost
- art/content requirements
- test complexity
- exploit surface
- future migration burden

Reusable systems are preferred, but v1.00 must not spend weeks building abstractions for hypothetical future content.

## Non-Negotiable Product Rules

- Tiny Factory must remain a factory game.
- Low population must not break the core experience.
- Important economy outcomes are server-authoritative.
- RNG creates choices; it does not replace decision-making.
- Common machines can remain strategically useful.
- Physical production must be readable and satisfying.
- No giant currency stack in v1.00.
- No prestige until the base factory is proven.
- No trading until security, duplication protection, economy controls, and actual demand justify it.
- No pet-simulator drift.

## Documentation Map

- `Game Design Document.md` — canonical evolving game design
- `Technical Architecture.md` — client/server, simulation, persistence, networking, performance
- `Machine Design Guide.md` — machine design rules and anti-bloat constraints
- `Economy Design.md` — economy, roll pricing, expansion, inflation, monetization boundaries
- `Analytics Plan.md` — validation instrumentation and metrics
- `Version Roadmap.md` — major-version scalability roadmap
- `Scope Classification.md` — strict Required Now / Valuable Later / Scope Creep classification
- `v1.00/` through `v4.00/` — version overview plus actionable implementation phases
