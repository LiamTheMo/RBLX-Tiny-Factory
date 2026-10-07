# Analytics Plan

The server sends privacy-safe event counts through Roblox `AnalyticsService:LogCustomEvent`. Use Creator Dashboard → Analytics → Custom to build dashboards for these events. Calls are protected so an analytics outage cannot interrupt gameplay. Player-level counters are also saved with the player record for local progress and funnel recovery.

## Release signals

| Question | Events |
| --- | --- |
| Do players return and reach a working factory? | `SessionStarted`, `ReturnSession`, `FactoryActive`, `SessionSeconds` |
| Do players reach the core loop? | `FirstItemProduced`, `FirstItemSold`, `FirstRoll` |
| Which systems get used? | `MachinePlaced`, `MachineRemoved`, `MachineMoved`, `MachineRolled`, `MachineRecycled`, `CapacityPurchased`, `LootCollected` |
| Is saving healthy? | `DataLoadFailure`, `DataSaveFailure` |

Event values are nonnegative integer increments. Avoid sending usernames, free-form text, or item-specific payloads. Start with event totals and compare them over time; the first-run milestones identify where players stop before producing or selling an item.

## Validation before release

In a published test place, trigger a fresh session and each core action, then confirm the custom events appear in Creator Dashboard. Confirm a returning session increments `ReturnSession`; force a data-store outage in a private test place and verify failures are logged without blocking the game loop. Dashboard availability and event processing may lag behind gameplay.
