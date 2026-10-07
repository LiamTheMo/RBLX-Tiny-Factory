# MVP Machine Catalog

Generated from shared definitions with `luau scripts/catalog_report.luau`. Base odds exclude Luck. Rarity is selected first, then the item weight within the entire rarity pool, including upgraders. Stats are starting playtest values; models remain provisional.

## Common

| Machine / stable ID | Category | Weight | Base odds (1/x) | Stats and behavior |
| --- | --- | ---: | ---: | --- |
| Cooldown Tuner / CooldownTuner | Processor | 2 | 65.00 | Provides a smaller, reliable throughput improvement. |
| Giantifier / Giantifier | Processor | 2 | 65.00 | Makes the item visibly larger. |
| Paint Machine / PaintMachine | Processor | 2 | 65.00 | Paints the item for later visual combinations. |
| Polished Roller / PolishedRoller | Processor | 5 | 26.00 | Adds a small value bonus to every cube. |
| Value Multiplier / ValueMultiplier | Processor | 3 | 43.33 | Doubles an item's value. |
| Coconut Crank / CoconutCrank | Producer | 4 | 32.50 | Standard; 5 base Coins; every 1.6s; type multiplier x1 |
| Crate Crafter / CrateCrafter | Producer | 7 | 18.57 | Standard; 3 base Coins; every 1.1s; type multiplier x1 |
| Dock Dropper / DockDropper | Producer | 6 | 21.67 | Standard; 6 base Coins; every 1.8s; type multiplier x1 |
| Island Starter / IslandStarter | Producer | 8 | 16.25 | Standard; 5 base Coins; every 1.5s; type multiplier x1 |
| Pebble Packer / PebblePacker | Producer | 4 | 32.50 | Standard; 10 base Coins; every 2.8s; type multiplier x1 |
| Sandstone Stamp / SandstoneStamp | Producer | 5 | 26.00 | Standard; 8 base Coins; every 2.2s; type multiplier x1 |
| Tin Toy Press / TinToyPress | Producer | 5 | 26.00 | Standard; 4 base Coins; every 1.35s; type multiplier x1 |
| Workshop Tap / WorkshopTap | Producer | 6 | 21.67 | Standard; 2 base Coins; every 0.9s; type multiplier x1 |
| Bulk Booth / BulkBooth | Seller | 3 | 43.33 | Pays x1.15 when processed base value is at least 20; otherwise x1. Accepts one sale every 1.8s. Sale cooldown: 1.8s. |
| Crate Counter / CrateCounter | Seller | 5 | 26.00 | Pays x1.05 for every cube. Accepts one sale every 1.4s. Sale cooldown: 1.4s. |
| Dockside Till / DocksideTill | Seller | 6 | 21.67 | Pays x0.9 for every cube. Accepts one sale every 0.65s. Sale cooldown: 0.65s. |
| Island Kiosk / IslandKiosk | Seller | 4 | 32.50 | Pays x1.1 for Standard cubes; other cubes pay x1. Accepts one sale every 1s. Sale cooldown: 1s. |
| Parcel Desk / ParcelDesk | Seller | 4 | 32.50 | Pays x0.85 for every cube. Accepts one sale every 0.4s. Sale cooldown: 0.4s. |
| Pocket Cashier / Seller | Seller | 2 | 65.00 | Pays the cube's full value reliably. Sale cooldown: 1s. |
| Stamp Stand / StampStand | Seller | 3 | 43.33 | Every 5th completed sale pays x1.25; otherwise x1. Accepts one sale every 1.1s. Sale cooldown: 1.1s. |
| Workshop Window / WorkshopWindow | Seller | 5 | 26.00 | Pays x1.1 when processed base value is at least 10; otherwise x1. Accepts one sale every 1.2s. Sale cooldown: 1.2s. |

## Uncommon

| Machine / stable ID | Category | Weight | Base odds (1/x) | Stats and behavior |
| --- | --- | ---: | ---: | --- |
| Breezy Bumper / BreezyBumper | Processor | 3 | 106.67 | Adds value to Air cubes only. |
| Compound Press / CompoundPress | Processor | 2 | 160.00 | Compresses an item into a higher-value form. |
| Conveyor Booster / ConveyorBooster | Processor | 2 | 160.00 | Speeds an item through downstream slots. |
| Moss Mixer / MossMixer | Processor | 3 | 106.67 | Adds value to Nature cubes only. |
| Rain Rinse / RainRinse | Processor | 3 | 106.67 | Adds value to Wet cubes only. |
| Breeze Bell / BreezeBell | Producer | 5 | 64.00 | Air; 5 base Coins; every 1.25s; type multiplier x1.1 |
| Dew Dripper / DewDripper | Producer | 3 | 106.67 | Wet; 4 base Coins; every 1.1s; type multiplier x1.15 |
| Pebble Press / EarthPress | Producer | 3 | 106.67 | Earth; 5 base Coins; every 2.1s; type multiplier x1.25 |
| Fast Dropper / FastDropper | Producer | 3 | 106.67 | Standard; 5 base Coins; every 0.8s; type multiplier x1 |
| Gust Gear / GustGear | Producer | 2 | 160.00 | Air; 3 base Coins; every 0.95s; type multiplier x1.1 |
| Leaf Lathe / LeafLathe | Producer | 3 | 106.67 | Nature; 8 base Coins; every 2.6s; type multiplier x1.2 |
| Mossy Maker / MossyMaker | Producer | 4 | 80.00 | Nature; 5 base Coins; every 2s; type multiplier x1.2 |
| Raincatcher / Raincatcher | Producer | 5 | 64.00 | Wet; 5 base Coins; every 1.8s; type multiplier x1.15 |
| Breeze Bazaar / BreezeBazaar | Seller | 3 | 106.67 | Pays x1.2 for Air cubes; other cubes pay x1. Accepts one sale every 0.85s. Sale cooldown: 0.85s. |
| Copper Counter / CopperCounter | Seller | 2 | 160.00 | Pays x1.1 for every cube. Accepts one sale every 1.5s. Sale cooldown: 1.5s. |
| Five Sale Stand / FiveSaleStand | Seller | 2 | 160.00 | Every 5th completed sale pays x1.5; otherwise x1. Accepts one sale every 0.8s. Sale cooldown: 0.8s. |
| Harbor Exchange / HarborExchange | Seller | 2 | 160.00 | Pays x1.2 when processed base value is at least 30; otherwise x1. Accepts one sale every 1.6s. Sale cooldown: 1.6s. |
| Leaf Ledger / LeafLedger | Seller | 3 | 106.67 | Pays x1.25 for Nature cubes; other cubes pay x1. Accepts one sale every 1.3s. Sale cooldown: 1.3s. |
| Quick-Count Counter / QuickCountCounter | Seller | 4 | 80.00 | Processes each sale in 0.5 seconds with a slightly lower payout. Sale cooldown: 0.5s. |
| Rain Market / RainMarket | Seller | 4 | 80.00 | Pays x1.2 for Wet cubes; other cubes pay x1. Accepts one sale every 1.1s. Sale cooldown: 1.1s. |
| Stone Scale / StoneScale | Seller | 3 | 106.67 | Pays x1.25 for Earth cubes; other cubes pay x1. Accepts one sale every 1.3s. Sale cooldown: 1.3s. |

## Rare

| Machine / stable ID | Category | Weight | Base odds (1/x) | Stats and behavior |
| --- | --- | ---: | ---: | --- |
| Ember Coater / EmberCoater | Processor | 3 | 200.00 | Adds value to Fire cubes only. |
| Frost Framer / FrostFramer | Processor | 2 | 300.00 | Adds value to Ice cubes only. |
| Static Stamper / StaticStamper | Processor | 3 | 200.00 | Adds value to Lightning cubes only. |
| Coal Kiln / CoalKiln | Producer | 2 | 300.00 | Fire; 9 base Coins; every 3.4s; type multiplier x1.35 |
| Copper Caster / CopperCaster | Producer | 2 | 300.00 | Metal; 5 base Coins; every 1.6s; type multiplier x1.3 |
| Ember Press / EmberPress | Producer | 4 | 150.00 | Fire; 5 base Coins; every 2.3s; type multiplier x1.35 |
| Frost Popper / FrostPopper | Producer | 3 | 200.00 | Ice; 5 base Coins; every 2.2s; type multiplier x1.35 |
| Heavy Dropper / HeavyDropper | Producer | 2 | 300.00 | Standard; 8 base Coins; every 2.4s; type multiplier x1 |
| Metal Molder / MetalMolder | Producer | 3 | 200.00 | Metal; 5 base Coins; every 2.4s; type multiplier x1.3 |
| Snowflake Stamp / SnowflakeStamp | Producer | 2 | 300.00 | Ice; 4 base Coins; every 1.4s; type multiplier x1.35 |
| Spark Sprout / SparkSprout | Producer | 3 | 200.00 | Lightning; 5 base Coins; every 2.5s; type multiplier x1.4 |
| Ember Outlet / EmberOutlet | Seller | 3 | 200.00 | Pays x1.4 for Fire cubes; other cubes pay x1. Accepts one sale every 1.4s. Sale cooldown: 1.4s. |
| Frost Fair / FrostFair | Seller | 3 | 200.00 | Pays x1.4 for Ice cubes; other cubes pay x1. Accepts one sale every 1.3s. Sale cooldown: 1.3s. |
| Metal Merchant / MetalMerchant | Seller | 2 | 300.00 | Pays x1.4 for Metal cubes; other cubes pay x1. Accepts one sale every 1.5s. Sale cooldown: 1.5s. |
| Premium Appraiser / PremiumAppraiser | Seller | 3 | 200.00 | Pays 15% more for cubes worth at least 25. Sale cooldown: 1.25s. |
| Quality Quay / QualityQuay | Seller | 2 | 300.00 | Pays x1.35 when processed base value is at least 50; otherwise x1. Accepts one sale every 1.8s. Sale cooldown: 1.8s. |
| Rapid Receipt / RapidReceipt | Seller | 2 | 300.00 | Pays x1 for every cube. Accepts one sale every 0.35s. Sale cooldown: 0.35s. |
| Spark Shop / SparkShop | Seller | 2 | 300.00 | Pays x1.45 for Lightning cubes; other cubes pay x1. Accepts one sale every 1.6s. Sale cooldown: 1.6s. |
| Type Collector / TypeCollector | Seller | 2 | 300.00 | Pays 30% more for Wet cubes. Sale cooldown: 1.25s. |

## Epic

| Machine / stable ID | Category | Weight | Base odds (1/x) | Stats and behavior |
| --- | --- | ---: | ---: | --- |
| Duplicator / Duplicator | Processor | 1 | 1944.44 | Creates one bounded additional item. |
| Goldenizer / Goldenizer | Processor | 1 | 1944.44 | Adds a golden visual state and bounded value bonus. |
| Lucky Lantern / LuckyLantern | Processor | 2 | 972.22 | One in ten cubes receives double value. |
| Time Twister / TimeTwister | Processor | 2 | 972.22 | Adds a strong bonus to Time cubes. |
| Amethyst Array / AmethystArray | Producer | 1 | 1944.44 | Crystal; 5 base Coins; every 2.1s; type multiplier x1.9 |
| Crystal Bloom / CrystalBloom | Producer | 2 | 972.22 | Crystal; 5 base Coins; every 3.3s; type multiplier x1.9 |
| Glow Garden / GlowGarden | Producer | 3 | 648.15 | Light; 5 base Coins; every 2.8s; type multiplier x1.5 |
| Hourglass Forge / HourglassForge | Producer | 1 | 1944.44 | Time; 10 base Coins; every 4.5s; type multiplier x1.8 |
| Moonlight Mill / MoonlightMill | Producer | 2 | 972.22 | Light; 5 base Coins; every 1.7s; type multiplier x1.5 |
| Shadow Spinner / ShadowSpinner | Producer | 2 | 972.22 | Shadow; 5 base Coins; every 3s; type multiplier x1.55 |
| Tide Turner / TideTurner | Producer | 2 | 972.22 | Wet; 7 base Coins; every 1.6s; type multiplier x1.15 |
| Time Ticker / TimeTicker | Producer | 2 | 972.22 | Time; 5 base Coins; every 3.2s; type multiplier x1.8 |
| Clockwork Clearing / ClockworkClearing | Seller | 2 | 972.22 | Pays x1.65 for Time cubes; other cubes pay x1. Accepts one sale every 2s. Sale cooldown: 2s. |
| Crystal Cashier / CrystalCashier | Seller | 2 | 972.22 | Pays x1.6 for Crystal cubes; other cubes pay x1. Accepts one sale every 1.8s. Sale cooldown: 1.8s. |
| Express Exchange / ExpressExchange | Seller | 1 | 1944.44 | Pays x1.05 for every cube. Accepts one sale every 0.3s. Sale cooldown: 0.3s. |
| Grand Appraiser / GrandAppraiser | Seller | 1 | 1944.44 | Pays x1.5 when processed base value is at least 100; otherwise x1. Accepts one sale every 2.2s. Sale cooldown: 2.2s. |
| Lucky Till / LuckyTill | Seller | 2 | 972.22 | One in eight sales receives a 50% bonus. Sale cooldown: 1.5s. |
| Shadow Auction / ShadowAuction | Seller | 2 | 972.22 | Pays x1.6 for Shadow cubes; other cubes pay x1. Accepts one sale every 1.7s. Sale cooldown: 1.7s. |
| Streak Register / StreakRegister | Seller | 2 | 972.22 | Every tenth sale pays double. Sale cooldown: 1.5s. |
| Sunlit Sales / SunlitSales | Seller | 2 | 972.22 | Pays x1.55 for Light cubes; other cubes pay x1. Accepts one sale every 1.5s. Sale cooldown: 1.5s. |

## Legendary

| Machine / stable ID | Category | Weight | Base odds (1/x) | Stats and behavior |
| --- | --- | ---: | ---: | --- |
| Lucky Modifier / LuckyModifier | Processor | 1 | 12000.00 | Alternates between bounded high and low value outcomes. |
| Rainbow Refractor / RainbowRefractor | Processor | 1 | 12000.00 | Further enhances Rainbow cubes. |
| Aurora Engine / AuroraEngine | Producer | 2 | 6000.00 | Rainbow; 4 base Coins; every 2.6s; type multiplier x2.5 |
| Chrono Cathedral / ChronoCathedral | Producer | 2 | 6000.00 | Time; 14 base Coins; every 5.2s; type multiplier x1.8 |
| Crystal Observatory / CrystalObservatory | Producer | 1 | 12000.00 | Crystal; 10 base Coins; every 3.6s; type multiplier x1.9 |
| Prism Bloom / PrismBloom | Producer | 1 | 12000.00 | Rainbow; 5 base Coins; every 3.8s; type multiplier x2.5 |
| Solar Foundry / SolarFoundry | Producer | 1 | 12000.00 | Light; 11 base Coins; every 3.4s; type multiplier x1.5 |
| Storm Spire / StormSpire | Producer | 2 | 6000.00 | Lightning; 7 base Coins; every 1.1s; type multiplier x1.4 |
| Tidal Monument / TidalMonument | Producer | 1 | 12000.00 | Wet; 9 base Coins; every 1.4s; type multiplier x1.15 |
| Void Loom / VoidLoom | Producer | 1 | 12000.00 | Shadow; 13 base Coins; every 4.1s; type multiplier x1.55 |
| Chrono Treasury / ChronoTreasury | Seller | 2 | 6000.00 | Pays x1.9 for Time cubes; other cubes pay x1. Accepts one sale every 2.3s. Sale cooldown: 2.3s. |
| Crystal Vault / CrystalVault | Seller | 2 | 6000.00 | Pays x1.85 for Crystal cubes; other cubes pay x1. Accepts one sale every 2.1s. Sale cooldown: 2.1s. |
| Festival Treasury / FestivalTreasury | Seller | 1 | 12000.00 | Every 5th completed sale pays x3; otherwise x1. Accepts one sale every 1.4s. Sale cooldown: 1.4s. |
| Prism Palace / PrismPalace | Seller | 2 | 6000.00 | Pays x2 for Rainbow cubes; other cubes pay x1. Accepts one sale every 2.5s. Sale cooldown: 2.5s. |
| Rainbow Exchange / RainbowExchange | Seller | 1 | 12000.00 | Pays 50% more for Epic and Legendary cube types. Sale cooldown: 2s. |
| Royal Registry / RoyalRegistry | Seller | 1 | 12000.00 | Pays x1.75 when processed base value is at least 250; otherwise x1. Accepts one sale every 2.8s. Sale cooldown: 2.8s. |
| Solar Syndicate / SolarSyndicate | Seller | 1 | 12000.00 | Pays x1.8 for Light cubes; other cubes pay x1. Accepts one sale every 1.8s. Sale cooldown: 1.8s. |
| Storm Clearinghouse / StormClearinghouse | Seller | 1 | 12000.00 | Pays x1.75 for Lightning cubes; other cubes pay x1. Accepts one sale every 1.25s. Sale cooldown: 1.25s. |

