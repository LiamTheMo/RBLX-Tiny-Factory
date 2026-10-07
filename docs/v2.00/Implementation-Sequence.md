# v2.00 Implementation Sequence

Status: planned; **no v2 implementation begins until v1.00 polished MVP acceptance**. Existing phase documents define the work; this sequence adds dependencies, evidence and release boundaries.

| Phase | Deliverable | Dependency / acceptance evidence |
| --- | --- | --- |
| 1 — Logistics Graph Foundation | Bounded node/edge model, deterministic scheduler, topology edits and versioned serializer | Accepted v1 MVP; v1 save fixtures migrate without lost machines, Coins or capacity; cycles and invalid edges rejected; existing linear factories remain usable. |
| 2 — Branching, Splitters & Mergers | Limited directional conveyors, clear previews, bounded split/merge queues | Phase 1; item/value conservation, no double sale, live edit safety; mobile branched build/save/rejoin pass. |
| 3 — Machine Framework Expansion | Reusable converters/sorters/conditional behavior that creates routing choices | Stable branching; preserve all MVP IDs/models; test compatibility, caps, strategy tradeoffs; avoid diluting RNG for cosmetic content alone. |
| 4 — Advanced Building, Inventory & Stats | Useful search/sort, atomic edits, server-derived production/bottleneck summaries | Phases 1–3; near-cap factories editable on phone/tablet; stats throttled and verified; existing category tabs reused. |
| 5 — Balance, Performance & v2 Validation | Migration, exploit, balance and multiplayer stress acceptance | All prior phases; several viable routes, measured performance and stable saves; owner acceptance and deployed main verification. |

## Work and deployment rules

For each phase: audit → new minor branch from v2.00 → implement → local validation → review/fix → revalidate → push/PR → merge v2.00 → check major CI → integrate main → check main validation/publish → deployed acceptance. Runtime bugs require new minor fix branches. All vX.XX checkpoints remain permanent. Do not add prestige, trading, extra currencies or social expansion to repair an unfinished MVP.

## Baseline carry-forward

Before Phase 1, reconcile the accepted v1 baseline into v2.00 through a minor branch and review; preserve schema version 4 until a tested sequential migration requires a bump. Compare actual graph behavior against this plan, not the old build label. Keep environment/machine art acceptance from v1 intact while adding logistics visuals.
