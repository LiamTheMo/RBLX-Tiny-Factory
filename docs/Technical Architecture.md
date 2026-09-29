# Technical Architecture

## 1. Architecture Goals

Tiny Factory's architecture should be:

- server-authoritative for economy and ownership
- modular enough to add machines cheaply
- simple enough to ship quickly
- deterministic enough to test
- efficient enough to simulate many visible items
- migration-safe
- analytics-aware
- mobile-friendly

The architecture should evolve with each version rather than front-loading v4.00 needs into v1.00.

## 2. Recommended Roblox Project Shape

A practical module split:

### Shared
- `MachineDefinitions`
- `MachineTypes`
- `ItemTypes`
- `EconomyConfig`
- `RarityConfig`
- `NetworkDefinitions`

### Server
- `FactoryService`
- `SimulationService`
- `MachineService`
- `InventoryService`
- `RollService`
- `EconomyService`
- `DataService`
- `AnalyticsService`
- `AntiExploitService`

### Client
- `FactoryViewController`
- `PlacementController`
- `InventoryController`
- `RollController`
- `HUDController`
- `EffectsController`
- `AudioController`

Exact names may change, but responsibilities should remain separated.

## 3. Server / Client Ownership

### Server authority
The server validates:

- roll result
- RNG seed/result path
- machine ownership
- machine inventory
- placement legality
- remove/move requests
- factory capacity
- production value
- seller rewards
- machine selling/recycling
- currency
- save writes
- progression rewards

### Client responsibility
The client may handle:

- placement preview
- local highlight state
- UI navigation
- camera
- interpolation
- cosmetic particles
- non-authoritative number popups
- local audio

Client messages should be treated as **requests**, never truth.

## 4. Factory Simulation — v1.00

Prefer deterministic lane/path simulation over physics.

A logical item can be represented by:

- item ID
- archetype
- current value
- compact state flags
- path progress
- source
- timestamps / processing state

The server advances logical progress at a controlled cadence.

The client renders item motion from replicated state or compact events.

### v1.00 simplification
Use one route and slot-index ordering. A machine processes an item when the item reaches its slot.

This avoids general graph traversal in the first release.

## 5. Machine Interface

Recommended conceptual interface:

1. `CanProcess(item, context)`
2. `Process(item, context)`
3. `GetProcessingTime(item, context)`
4. optional `OnPlaced(factoryContext)`
5. optional `OnRemoved(factoryContext)`

Machine definitions should be data-driven where practical:

- ID
- display name
- rarity
- category
- model key
- description
- parameters
- processing delay
- tags
- unlock state
- analytics ID

v1.00 should not force every hypothetical field.

## 6. Machine Behavior Architecture

Use a hybrid approach:

- configuration for common numeric machines
- reusable behavior modules for recurring mechanics
- bespoke modules only for genuinely unique machines

Example behavior modules:

- `MultiplyValue`
- `ScaleVisual`
- `SetMaterial`
- `DuplicateItem`
- `RandomMultiplier`
- `AdjustThroughput`

A new ×2 vs ×3 stamper should not require entirely separate systems.

## 7. Item Architecture

v1.00 item state should remain compact.

Suggested fields:

- `ArchetypeId`
- `BaseValue`
- `Value`
- `VisualState`
- `SizeTier` or scalar if needed
- `Tags`
- `SourceMachineId`
- short transformation history only if needed for rules/analytics

Do not store:

- full per-frame position
- cosmetic effect state
- transient UI state
- unnecessary provenance

## 8. Placement System

### v1.00
- predefined slots
- server checks slot ownership and occupancy
- client previews
- move is represented as remove + validated place transaction
- rotation may be visual-only where slot path determines flow

### v2.00
Expand to:
- modular conveyor graph
- tile/grid validation
- branch connectivity
- direction rules
- split/merge nodes
- stronger layout serialization

## 9. Inventory

v1.00 inventory entries can be compact stacks where machine instances do not need unique metadata.

If every identical Basic Dropper is equivalent, store quantity by machine ID.

Only introduce per-instance IDs when required for:

- upgrades
- cosmetics
- affixes
- ownership tracking
- trading

Avoid premature unique-instance complexity.

## 10. Roll System

Rolls run on the server.

Pipeline:

1. validate request, server cooldown, and inventory space
2. reserve the next server cooldown
3. select rarity using server config
4. select eligible machine from pool
5. grant inventory item
6. record analytics
7. return result

Add rate limits and idempotency where duplicate network delivery could matter.

## 11. Economy

Server calculates all sale value.

Never trust:

- client-reported item value
- client-reported machine count
- client-reported production speed
- client-reported roll outcome

Use bounded numeric representations and sanity checks.

## 12. Saving

v1.00 persistent state:

- schema version
- Coins
- inventory
- placed machine layout
- unlocked capacity
- discovered machine IDs
- compact player statistics

Do not save in-flight items.

Recommended safeguards:

- schema versioning from day one
- default-safe reads
- retry/backoff strategy
- session lock or conflict protection
- bounded save size
- mutation through service APIs rather than arbitrary table edits

## 13. Data Migration

v1.00 only needs a lightweight migration framework:

`SavedSchemaVersion -> migrate sequentially -> CurrentSchemaVersion`

v4.00 can add stronger tooling, dry runs, audit logs, rollback support, and migration dashboards.

## 14. Analytics Architecture

Analytics events should be emitted from authoritative systems when possible.

Examples:

- free roll granted
- machine granted
- machine placed
- machine removed
- machine sold
- production milestone
- capacity purchased
- session factory rebuild count

Avoid duplicating analytics calls throughout UI code.

## 15. Networking

Use explicit remotes by responsibility or a well-typed network layer.

Validate:

- argument types
- IDs against known definitions
- ownership
- rate limits
- capacity
- placement range/slot
- transaction state

Do not expose general-purpose “set value” remotes.

## 16. Anti-Exploit

Primary v1.00 risks:

- fake sale value
- roll result spoofing
- free roll spam
- machine duplication
- invalid placement
- inventory underflow/overflow
- remote flooding
- save rollback abuse

Mitigation is mostly achieved through server ownership and transactional APIs.

## 17. Performance

### Primary risk
Visible item count can grow faster than machine count.

v1.00 safeguards:

- active item cap per factory
- deterministic movement
- no item-item collision
- pooled visual objects
- low-frequency logical simulation where possible
- event-driven processing
- distance-based effect reduction
- throttled UI counters
- no expensive heartbeat loop per machine

### Later
v2.00+ may add:

- factory sleep states
- batch/offline simulation for inactive factories
- LOD
- server load budgeting
- profiling hooks
- per-machine cost instrumentation

## 18. Evolution by Major Version

### v1.00
Single-route simulation, compact data, small content table, basic migrations.

### v2.00
Graph-based or node-based logistics, richer machine behavior composition, stronger build serialization, more performance instrumentation.

### v3.00
Persistent research/collection layers, social read models, records, challenge state, optional co-op authority.

### v4.00
Data-driven content pipeline, validators, feature flags, migration tooling, admin/debug utilities, rollback safety, automated simulation tests, economy observability.

## 19. Overengineering Guardrail

Do not build these for v1.00:

- generic distributed simulation framework
- market-grade unique item ledger
- full live-ops remote config platform
- graph compiler for hypothetical future conveyors
- dozens of empty abstraction layers
- offline production simulation unless actual design requires it

Ship the smallest architecture that can safely answer the v1.00 product question.
