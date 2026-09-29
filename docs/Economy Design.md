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
- rarity weights that keep common machines strategically useful

Exact numbers must come from playtests.

## 4. Machine Recycling

Recycling an unwanted machine frees one inventory slot and returns no Coins.

Purpose:

- keep inventory usable
- avoid converting free rolls into unlimited Coins

The conveyor seller and world Coin drops are the ways this prototype earns Coins.

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

Rarity may influence average expected power but should not map directly to one fixed multiplier ladder.

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
- rarity weights
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
