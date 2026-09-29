# Analytics Plan

## 1. Purpose

Tiny Factory is a validation project. Analytics should answer:

> Are players experimenting with their factories, or merely waiting for numbers to rise?

Collect only data that supports product, economy, performance, or exploit decisions.

## 2. v1.00 Core Funnel

Track:

1. session start
2. factory becomes active
3. first item produced
4. first item sold
5. first roll
6. first machine granted
7. first machine placed
8. first machine moved/replaced
9. first capacity upgrade
10. production milestones
11. session end
12. return session

## 3. Machine Interaction Events

Recommended events:

- `MachineRolled`
- `MachinePlaced`
- `MachineMoved`
- `MachineRemoved`
- `MachineSold`
- `MachineProcessedItem`
- `MachineDiscovery`
- `FactoryLayoutChanged`

Do not emit excessively high-volume per-item events to remote analytics if aggregation is sufficient.

## 4. Key Derived Measures

- time to first sale
- time to first roll
- time to first placement
- rolls per session
- unique machine types used
- layout changes per session
- machine removal/replacement rate
- percentage of players who reorganize after initial placement
- capacity upgrade conversion
- production milestones reached
- machine usage distribution
- session duration
- return behavior

## 5. Experimentation Signals

Strong signs of experimentation:

- moving machines after they already work
- changing order
- replacing a higher-rarity machine with a lower-rarity one
- repeatedly testing combinations
- using multiple distinct categories
- revisiting factory layout after new rolls

Weak signals:

- never opening build mode after first setup
- leaving initial machines untouched
- income rising mostly through passive time
- high roll counts but low placement diversity

## 6. Economy Analytics

Track aggregated:

- Coins earned
- free rolls accepted and cooldown rejections
- Coins spent on expansion
- machines recycled from inventory
- production rate bands
- roll rarity distribution
- machine ownership distribution
- dominant chain patterns where feasible

Watch for inflation and outliers.

## 7. Performance Analytics

Capture useful operational indicators:

- active item count distribution
- factory machine count
- simulation step cost
- remote/event rate
- save payload size
- save failures
- server memory trends
- client frame-rate/device class where platform tools safely support it

## 8. Security Signals

Flag suspicious patterns:

- impossible request frequency
- repeated rejected transactions
- impossible placement requests
- currency deltas outside legal sources
- duplicate request IDs
- save/load conflicts
- abnormal production compared with legal simulated upper bounds

## 9. v1.00 Validation Dashboard Questions

The launch review should be able to answer:

- Do players reach the first roll?
- Do they place what they roll?
- Do they later move or replace machines?
- Which machines are ignored?
- Are any machines universally dominant?
- Where do players quit?
- Do players buy capacity?
- Does production pacing stall?
- Are there clear exploit or performance outliers?
- Do meaningful players return?

## 10. Provisional Product Targets

Any thresholds used before launch must be labeled **provisional**.

Suggested pre-launch internal test expectations:

- most testers understand the produce → modify → sell loop without explanation
- most testers can place/move a machine on desktop and mobile
- testers voluntarily rebuild at least once when given several machine options
- no single launch machine is an obvious always-pick in every test layout

Public success thresholds should be set only after obtaining real baseline data.

## 11. Later Analytics

### v2.00
- branch usage
- splitter/merger patterns
- throughput bottlenecks
- machine synergy frequency
- layout complexity

### v3.00
- collection progress
- research choices
- challenge participation
- visiting/showcase behavior
- social retention lift

### v4.00
- event participation
- machine pool health
- economy drift
- live config impact
- content pipeline errors
- migration status
- feature flag cohorts
