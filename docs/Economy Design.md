# Economy Design

## 1. Economy Goal

The economy exists to generate **factory decisions**.

Free rolls should create new machine choices; Coins earned from production and pickups unlock modest capacity.

## 2. v1.00 Currency

Use one currency:

- **Coins**

Coins are earned by selling factory items.

Coins are spent on:

- limited factory capacity upgrades

Do not add a second currency unless a validated problem cannot be solved cleanly with Coins.

## 3. Roll Pacing

Rolls are free. The server enforces a short cooldown between successful rolls so clients cannot spam inventory grants.

Recommended model:

- a configurable three-second cooldown for the prototype
- a bounded inventory with recycling for unwanted machines
- distinct per-machine roll chances that total 100%

Exact numbers must come from playtests.

## 4. Machine Recycling

Recycling an unwanted machine frees one inventory slot and returns no Coins.

Purpose:

- keep inventory usable
- avoid converting free rolls into unlimited Coins

The conveyor Seller and stored Coin boosters earn Coins. Other stored world boosters grant temporary effects, not new currencies. The Machines tab groups installed and available machines into Droppers, Upgraders, and Sellers; recycling acts only on an available copy. The Boosters tab shows collected item modifiers with an explicit Use action.

## 5. Factory Expansion

Capacity upgrades are the only Coin purchase in this prototype.

This creates a useful choice:

> Which machines should I keep, and when should I buy room for stronger combinations?

Keep expansion steps few and legible in v1.00.

## 6. Production Curve

Desired pacing characteristics:

- immediate visible improvement in first minutes
- early machine changes noticeably affect income
- no trillion-scale numbers immediately
- expansion feels earned
- a strong synergy creates a spike without permanently breaking pacing
- economy remains understandable without scientific notation during early play

## 7. Strategy Profiles

The economy should eventually support different viable styles:

- high-volume / low-value
- low-volume / high-value
- duplication
- transformation chains
- risk/random
- throughput optimization

v1.00 only needs enough variety to prove that players notice these differences.

## 8. Rarity and Economy

Every rollable machine has its own configured roll chance. The server selects from those machine-specific chances, and rarity is derived from the exact reciprocal chance; it is not assigned first and then used to group equal-probability machines.

| Rarity | Reciprocal denominator |
| --- | --- |
| Common | 1 to 100 |
| Uncommon | greater than 100 to 500 |
| Rare | greater than 500 to 2,500 |
| Epic | greater than 2,500 to 10,000 |
| Legendary | greater than 10,000 |

Each upper denominator limit is inclusive: for example, 1/100 is Common and odds just rarer than 1/100 are Uncommon. Legendary is the final open-ended band; a future tier can be inserted by adding an ordered rarity-band entry before it.

The ordered rarity bands, denominator limits, pastel reveal colors, and luck biases are defined once in shared economy configuration. Rollable machines keep distinct weighted chances alongside their definitions; rarity and displayed 1/x odds are derived from the active weighted pool. Without a booster, the configured base chance total remains 100%. A temporary Luck booster modestly increases weights in higher rarity bands using each band's `LuckBias`; Common stays unchanged, the overall pool is renormalized, and the server caps the multiplier and duration. Inventory odds continue to describe the base chances, while an active roll reveal uses boosted effective odds.

Roll animation samples show machine name and reciprocal odds on one readable line. Rarity is shown through the pastel reveal color and final heading (for example, `RARE MACHINE!`) instead of repeating it in that line. A configurable cosmetic cutscene plays when the final effective odds denominator is greater than 10,000; the exact 1/10,000 boundary does not trigger it. Studio tests invoke the shared presentation event to verify the cutscene without relying on a live ultra-rare result.

Random world boosters are defined in `BoosterConfig` and validated by pure `BoosterRules`. The starter set grants Coins or a temporary 2x Luck effect. Drops appear around factory plots, are public to all players, and enter a bounded, persistent booster inventory on Humanoid touch after their landing animation. The server applies their configured rewards only when the player uses them from inventory. A downward raycast selects a collidable land surface while ignoring plots and water; the server validates collection and use. Weights, colors, values, spawn bounds, fall timing, and lifetimes are centralized so new booster types can be added as definitions without duplicating reward logic.

Seller is a rollable machine definition with a configured 2% base chance. The factory requires exactly one Seller in its dedicated end bay. A newly rolled Seller may replace the old one transactionally; any previously saved movable Seller is migrated into the bay.

Production cubes wait for contact with the server-owned Seller hitbox before the sale is settled. The server calculates currency from the processed cube value plus additive bonuses from its output type, active sale buffs, and Seller, then applies those layers' multipliers, floors to whole Coins, and caps the payout. The cube is removed and sale statistics are updated in the same transaction as the wallet credit. Luck remains a roll-odds buff and does not change sale value.

The configured base machine chances total 100%. Current values are starting balance data for playtests. Rarity may influence average expected power, but should not map directly to a fixed multiplier ladder.

Avoid:

Common = ×2  
Uncommon = ×5  
Rare = ×20  
Epic = ×100  
Legendary = ×1000

That structure quickly makes earlier machines irrelevant.
## 9. Inflation Risks

Watch for:

- multiplicative modifiers stacking without limits
- duplication before every multiplier
- speed increases creating runaway spawn counts
- exponential capacity expansion
- free-roll recycling accidentally awarding Coins
- offline income trivializing active factory decisions

## 10. Balance Controls

Keep critical values in configuration:

- base drop values
- drop intervals
- processing delays
- multipliers
- roll cooldown and inventory cap
- per-machine roll chances and rarity odds thresholds
- expansion prices
- active item caps

Balance through data rather than code changes where possible.

## 11. Prestige Philosophy

Prestige is **not** part of v1.00.

It may be considered later only if it:

- opens new factory strategies
- introduces meaningful permanent choices
- changes machine availability or layout options
- creates a satisfying reset cadence

Reject prestige if it is merely “reset for +10% money.”

## 12. Monetization Boundaries

Do not make the validation loop pay-to-win.

Avoid:

- paid luck
- paid rare machine rolls
- direct paid production multipliers
- premium-only optimal machines
- pressure-driven reroll monetization

Prefer later:

- machine skins
- conveyor skins
- plot themes
- decorative props
- cosmetic item trails
- cosmetic roll reveals
- supporter cosmetics

## 13. Provisional Balance Targets

These are **test targets, not success guarantees**:

- first roll should be reachable quickly enough that the player understands the loop in the opening session
- first capacity expansion should occur after the player has already experimented with multiple machines
- a single rare machine should feel strong without multiplying income by orders of magnitude alone
- players should have meaningful reasons to change layouts throughout the early session

All exact tuning must be data-driven.

## Production feedback and numeric presentation

The server publishes the wallet immediately when a Seller settles a cube. The economy panel listens to `FactoryCoins` changes and `ItemSold` confirmations, so production income is visible without rolling or opening inventory. Sale popups are cosmetic client effects; they never grant currency.

`MaxItemValue` caps each cube independently. `MaxCoins` caps the wallet at the largest exact integer representable by a double, and save sanitization uses that wallet limit. Display formatting never changes stored currency or increases the numeric precision of gameplay calculations.

Shared `NumberFormatter.format(number)` renders exactly two decimals, with 102 groups through centillion: k, m, b, t, qd, qt, sx, sp, oc, no, dc, and compound suffixes. It promotes suffixes after rounding, handles signs, and avoids negative zero. `NumberFormatter.integer(number)` keeps small counters as integers and abbreviates large counters with two decimals. Use these helpers for currencies, multipliers, popups, and future high-number UI.

Hovered cubes display their current full sale value, output type, effective upgrade multiplier, sale multiplier, upgrade labels, and non-neutral type/buff/Seller layers. The preview changes as the cube is upgraded or buffs expire; subsequent upgrades can change the final payout. Touch devices can tap a cube to inspect it briefly.

Every current machine has a configured palette, symbol on its housing, and small silhouette details in `MachineVisualConfig.Variants`. `MachineModelBuilder` shares the base shells and builds these details, keeping the section holograms separate.

Manual validation on the deployed place: verify live Coins growth without inventory actions, hover/tap a normal and upgraded cube, confirm rising sale text at the open Seller intake, compare every machine variant, and test readability/performance on desktop and mobile.
