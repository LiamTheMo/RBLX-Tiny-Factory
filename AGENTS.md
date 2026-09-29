# Tiny Factory — Agent and Contributor Instructions

## Project status

Tiny Factory is a Roblox incremental/factory game. `main` contains the
integrated release, and `v0.01` through `v0.06` are permanent cumulative phase
checkpoints. The local implementation contains the complete Phase 1–6 v1
candidate. Automated validation is complete. Roblox Studio manual validation
and remote GitHub synchronization are release handoff steps when credentials
and a testable Roblox target are available.

### Cumulative phase checkpoints

| Branch | Included work |
| --- | --- |
| `v0.01` | Existing permanent Phase 1/v1 foundation baseline |
| `v0.02` | Phase 2 building and placement workflow |
| `v0.03` | Phase 3 rolling, inventory, resale, and economy presentation |
| `v0.04` | Phase 4 readable launch machines and feedback |
| `v0.05` | Phase 5 persistence, analytics, and runtime hardening |
| `v0.06` | Phase 6 onboarding, release polish, and checkpoint CI coverage |

`v1.00` is the release candidate assembled from the completed v0 checkpoints.

The product question for `v1.00` is:

> Is building a factory from random machines fun enough that players repeatedly
> change their layouts?

The factory is the product. Do not let generic simulator conventions, extra
currencies, passive number growth, or social features replace the visible
produce → transform → sell → roll → rebuild loop.

The current local v1 implementation includes deterministic bounded simulation,
server-authoritative placement and economy, a twelve-machine launch set,
responsive build/economy HUDs, schema-versioned persistence with session locks,
bounded analytics, and a Tiny Factory-only validation/deployment workflow.

## Required Git workflow

The major branches are permanent checkpoints. Only `main` and branches named
`vX.XX` are major branches.

1. Audit the repository, branch, requirements, and existing validation state.
2. Start from the intended major branch. For current v1 work, use `v1.00`;
   earlier version branches remain historical checkpoints.
3. Create a descriptive temporary/minor branch for every change. Never develop
   directly on `main` or a `vX.XX` branch.
4. Implement one coherent change set on the temporary branch.
5. Validate with the relevant tests, compilers, build checks, security checks,
   and manual checklist.
6. Review the diff and any CI/review findings, fix actionable issues, and
   revalidate.
7. Commit and push the temporary branch, open a pull request into its origin
   major branch, and merge it only after validation.
8. Push the updated major branch.
9. Merge the completed major branch into `main` only when the release/version is
   intended for integration or deployment.

Deployment is allowed only from `main` under the repository's deployment policy.
Do not publish from temporary or version branches. Never delete a completed
`vX.XX` branch, force-push it, or rewrite its history without explicit approval.

When credentials or a connector prevent a push, keep the local branch and
working tree safe, report the exact handoff, and do not pretend that a remote
branch, pull request, merge, or deployment succeeded.

## Documentation authority and reading order

Before changing architecture or scope, read the complete relevant documents. The
canonical documentation set is:

- `docs/README.md` — product premise, core loop, priorities, and non-negotiables.
- `docs/DOCUMENTATION INDEX.md` — documentation map.
- `docs/Game Design Document.md` — player-facing design and v1 constraints.
- `docs/Technical Architecture.md` — ownership, services, simulation, data, and
  networking boundaries.
- `docs/Machine Design Guide.md` — machine acceptance and balancing rules.
- `docs/Economy Design.md` — Coins, rolls, resale, expansion, and economy limits.
- `docs/Analytics Plan.md` — validation funnel and authoritative event signals.
- `docs/Version Roadmap.md` — purpose and scalability boundary for each major
  version.
- `docs/Scope Classification.md` — Required Now / Valuable Later / Scope Creep.
- `docs/Future Directions.md` — explicitly conditional post-v4 ideas.
- `docs/v1.00/` — the complete v1 phase plan and exit criteria.
- `docs/v2.00/`, `docs/v3.00/`, and `docs/v4.00/` — future constraints that
  should inform compatibility without pulling future scope into v1.

All of the above documentation was read during creation of this file. The
documentation is intentionally validation-first: a roadmap item is not proof
that the feature belongs in the current release.

## Current audit findings

The initial repository is a scaffold, not a playable game. At the start of
Phase 1:

- only `src/client/init.client.luau` and `src/server/init.server.luau` existed;
- the entrypoints referenced missing Tank Blast modules;
- `default.project.json` referenced a missing `src/maps` directory;
- the deployment workflow was copied from Tank Blast and targeted `v0.05`;
- the deployment workflow referenced missing `tests/`, test projects, and Phase
  2–5 Tank Blast tooling;
- the deployment workflow was named for Tank Blast;
- no Tiny Factory simulation, definitions, tests, persistence, build UI, or
  deployment target configuration existed;
- there was no existing major version branch before `v0.01`.

These are tracked as foundation work. Do not preserve copied Tank Blast names,
services, tests, or deployment assumptions when implementing Tiny Factory.

## Product boundaries for v1.00

### Required v1 systems

- one player plot and one deterministic production route;
- server-owned producer → path → processor → seller simulation;
- compact logical item state and a strict active-item cap;
- Coins as the only v1 currency;
- machine placement, movement, removal, inventory, free rolling, recycling, and a few
  capacity upgrades;
- approximately twelve machines only if they create distinct decisions;
- schema-versioned persistence and basic analytics;
- explicit remote validation and rate limits;
- readable desktop and mobile building controls;
- enough audio/visual feedback for honest validation testing.

### Explicitly not v1 scope

Do not add prestige, trading, player marketplaces, clans, PvP, pets, multiple
worlds, a second currency, paid luck, a modular conveyor graph, splitters,
mergers, social progression, or a large live-ops framework. These belong to
later versions only when v1 evidence justifies them.

## Architecture rules

### Server authority

The server owns item creation, item processing, sale value, Coins, RNG, machine
ownership, inventory, placement legality, capacity, persistence, and progression
rewards. Client input is always a request. Never accept client-reported value,
roll results, machine counts, production speed, or currency changes.

### Deterministic Phase 1 simulation

Phase 1 uses one route represented by ordered slots. The logical simulation must
not depend on unrestricted Roblox physics or item-item collisions. A simulation
step advances logical progress and processes items at slots; visual rendering
may interpolate separately on the client.

The simulation must enforce:

- finite active items per factory;
- bounded numeric values;
- deterministic processing order;
- explicit machine processing contracts;
- safe handling of congestion and full caps;
- no per-item or per-machine unbounded heartbeat connections.

### Module boundaries

Keep pure configuration and simulation math testable outside Roblox services.
Use shared modules for definitions and pure contracts, server services for
authoritative state and mutations, and client controllers for presentation and
input. A feature that changes Coins or durable ownership must not be implemented
only in a client controller.

Recommended eventual structure:

```text
src/shared/
  Config/
  Definitions/
  Simulation/
  Types/
src/server/
  Services/
  Infrastructure/
src/client/
  Controllers/
  UI/
tests/
```

Use the smallest structure that keeps responsibilities clear. Do not create
empty abstractions for v2–v4 systems.

## Machine contracts

Every machine definition must have a stable ID, display name, rarity/category,
description, processing behavior, and bounded parameters. A machine must answer:

1. What decision does it create?
2. Does order matter?
3. Is its effect visible and understandable?
4. Is it computationally bounded?
5. Can an existing reusable behavior express it?
6. Does it preserve a role for other machines?

Use reusable behaviors for common numeric/value/visual/throughput mechanics.
Keep bespoke logic isolated. Rarity is not a universal power ladder; Common
machines must remain strategically useful.

## Economy and security rules

Rolls are free with a server-owned cooldown; Coins fund limited capacity upgrades.
All economy mutations must be
transactional, bounded, server-side, and observable. Inventory operations must
conserve items: a failed move, sell, or placement must not destroy or duplicate
ownership. Use request IDs or equivalent idempotency protection where retries
could repeat a mutation.

Rate-limit remotes, validate types and IDs against trusted definitions, validate
ownership and slot capacity, reject malformed values, and log meaningful
rejections without exposing sensitive state to clients.

Do not add monetization to the v1 validation loop. Paid luck, premium optimal
machines, and direct production multipliers are prohibited in v1.

## Persistence and analytics rules

Do not persist transient conveyor items. The v1 durable model will contain only a
schema version, Coins, compact inventory, placed layout, unlocked capacity,
discovered IDs, and compact player statistics. All reads must default safely and
future migrations must be sequential and testable.

Authoritative systems emit analytics events. Important signals include first
production/sale/roll/place/move, rolls per session, layout changes, machine
usage, capacity purchases, production milestones, quit points, return sessions,
save failures, rejected requests, and active-item/performance bands. Do not emit
unbounded per-item external telemetry.

## Validation loop

Every feature follows this loop:

1. Audit current state and requirements.
2. Implement the smallest complete change.
3. Run format/lint/type/compile/tests/build checks available in the repository.
4. Review the diff for scope drift, security, duplication, dead code, and
   maintainability.
5. Apply fixes.
6. Re-run validation.
7. Record remaining manual validation and blockers.

Phase 1 must at minimum validate pure item/value math, cap behavior, producer →
processor → seller flow, deterministic order, numeric bounds, and isolation of
two factories. Later phases add placement, economy, persistence, and full launch
validation suites.

## Manual validation expectations

Automated checks cannot prove feel or Roblox runtime behavior. Mark these for
manual testing when implemented:

- the first item is visible and reaches the seller;
- processing changes are visually understandable;
- long-running production does not stall;
- the active-item cap degrades gracefully;
- two players' factories remain isolated;
- desktop and mobile placement are usable;
- machine order creates real choices;
- reconnect restores only valid durable state;
- maximum intended item/machine configuration remains performant.

## Deployment and workflow configuration

Deployment must be fail-closed and restricted to merges into an approved major
branch only after the project-specific verification suite passes. Before enabling
publishing, replace the inherited Tank Blast workflow with a Tiny Factory
workflow, use the current deployment branch policy, remove missing test paths,
and verify Roblox target secrets without printing them. No temporary or version
branch may publish directly.

## Definition of done for v1.00

The Phase 1–6 implementation is complete when all phase tests, compilation,
Rojo build, release checks, and code review pass. A public `v1.00` release still
requires the following Roblox Studio acceptance checks on the published place:

- [ ] New-player no-explanation first-minute test.
- [ ] Desktop full loop: roll, place, produce, sell, and expand.
- [ ] Mobile full loop with safe touch targets and readable labels.
- [ ] Reconnect and session-lock behavior.
- [ ] Multiplayer plot isolation.
- [ ] Prolonged idle production and worst-case machine chain.
- [ ] Audio/visual readability and performance on the target devices.
- [ ] Analytics events and build label are visible in the intended review path.
- [ ] Deployment verification and publish run from `main` only.

Automated validation is not a substitute for these engine/manual checks.

## Change checklist

Before committing:

- [ ] Correct temporary branch is active.
- [ ] Relevant docs and current implementation were audited.
- [ ] No copied Tank Blast names or assumptions remain in changed code.
- [ ] Server authority and remote validation are preserved.
- [ ] Numeric values and collection sizes are bounded.
- [ ] Pure logic has automated coverage where practical.
- [ ] Client code is not trusted for economy or ownership.
- [ ] Scope remains inside the active phase.
- [ ] Relevant build/test/lint checks pass.
- [ ] Diff and manual validation list were reviewed.
- [ ] Commit is ready for temporary-branch push and PR into the origin major.
