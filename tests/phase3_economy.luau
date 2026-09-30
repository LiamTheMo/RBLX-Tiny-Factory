--!strict

local EconomyConfig = require("../src/shared/EconomyConfig")
local EconomyRules = require("../src/shared/EconomyRules")
local MachineDefinitions = require("../src/shared/MachineDefinitions")
local BoosterConfig = require("../src/shared/BoosterConfig")
local BoosterRules = require("../src/shared/BoosterRules")
local SaleValueRules = require("../src/shared/SaleValueRules")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local firstRollCost = EconomyRules.getRollCost(0)
local secondRollCost = EconomyRules.getRollCost(1)
expect(firstRollCost == 0, "the first roll should be free")
expect(secondRollCost == 0, "every roll should be free")

local layeredSale = SaleValueRules.calculate(
	10,
	{ AdditiveBonus = 2, Multiplier = 1.5 },
	{ AdditiveBonus = 3, Multiplier = 2 },
	{ AdditiveBonus = 4, Multiplier = 1.25 },
	1000
)
expect(layeredSale == 71, "sale value should add all bonuses before multiplying and flooring")
expect(
	SaleValueRules.calculate(10, { AdditiveBonus = 1, Multiplier = 1.5 }, nil, { AdditiveBonus = 2, Multiplier = 2 }, 1000) == 39,
	"seller modifiers should still apply when no buff layer is active"
)
expect(SaleValueRules.calculate(10, nil, nil, nil, 5) == 5, "sale value should respect the configured item-value cap")
expect(SaleValueRules.calculate(10, { AdditiveBonus = math.huge, Multiplier = 0 }, nil, nil, 100) == 10, "invalid type modifiers should fall back to neutral values")
expect(SaleValueRules.calculate(math.huge, nil, nil, nil, 100) == nil, "non-finite item values must not be sold")

local rollPool = MachineDefinitions.getRollPool()
local rarityBands = EconomyConfig.RarityOddsBands
local seenRarities: { [string]: boolean } = {}
local expectedRarityColors = {
	Common = { 217, 217, 222 },
	Uncommon = { 191, 232, 197 },
	Rare = { 184, 216, 240 },
	Epic = { 215, 184, 232 },
	Legendary = { 240, 168, 143 },
}
local previousMaxDenominator = 0
local expectedLuckBias = { Common = 0, Uncommon = 0.25, Rare = 0.5, Epic = 0.75, Legendary = 1 }
expect(#rarityBands > 0, "at least one rarity band must be configured")
for index, band in ipairs(rarityBands) do
	local rarityName = band.Name :: string
	local maxDenominator = band.MaxDenominator :: number
	local color = band.Color
	expect(rarityName ~= "", "rarity bands need readable names")
	expect(not seenRarities[rarityName], "rarity band names must be unique")
	seenRarities[rarityName] = true
	expect(maxDenominator > previousMaxDenominator, "rarity bands must follow increasing odds limits")
	expect(type(color) == "table" and #color == 3, "each rarity band needs an RGB display color")
	expect(type(band.LuckBias) == "number" and band.LuckBias >= 0 and band.LuckBias <= 1, "rarity luck bias must be bounded")
	local expectedBias = expectedLuckBias[rarityName]
	if expectedBias then expect(band.LuckBias == expectedBias, "configured rarity luck bias changed unexpectedly") end
	for _, channel in ipairs(color) do
		expect(type(channel) == "number" and channel % 1 == 0 and channel >= 0 and channel <= 255, "rarity display colors must use RGB channels from 0 to 255")
	end
	local expectedColor = expectedRarityColors[rarityName]
	if expectedColor then
		expect(color[1] == expectedColor[1] and color[2] == expectedColor[2] and color[3] == expectedColor[3], `{rarityName} pastel color is incorrect`)
	end
	expect(EconomyRules.getRarityFromOdds(maxDenominator) == rarityName, "each configured odds limit must map to its rarity")
	if index < #rarityBands then
		local nextBand = assert(rarityBands[index + 1])
		expect(EconomyRules.getRarityFromOdds(maxDenominator + 0.01) == nextBand.Name, "odds above a rarity limit must enter the next band")
	end
	previousMaxDenominator = maxDenominator
end
local finalRarityBand = assert(rarityBands[#rarityBands])
expect(finalRarityBand.Name == "Legendary" and finalRarityBand.MaxDenominator == math.huge, "Legendary should remain the open-ended final band")
expect(EconomyRules.getRarityFromOdds(1) == rarityBands[1].Name, "1/1 should use the most common configured band")
expect(EconomyRules.getRarityFromOdds(12) == "Common", "1/12 should be Common in the configured bands")
expect(not EconomyRules.getRarityFromOdds(0), "zero denominator should not have a rarity")
expect(EconomyRules.getMachineOddsDenominator("FastDropper", rollPool) == 20, "machine odds denominator should follow its configured weight")
expect(not EconomyRules.shouldPlayUltraRareCutscene(10000), "the ultra-rare cutscene should not include the exact 1/10,000 boundary")
expect(EconomyRules.shouldPlayUltraRareCutscene(10000.01), "the ultra-rare cutscene should include odds rarer than 1/10,000")
expect(EconomyRules.getMachineOddsLabel("Seller", rollPool) == "1/50", "rollable seller odds should follow its configured two-percent chance")
local sellerDefinition = MachineDefinitions.get("Seller")
expect(sellerDefinition ~= nil and sellerDefinition.Rollable, "the seller should be part of the roll pool")
local totalChance = 0
for _, definition in ipairs(rollPool) do
	totalChance += definition.RollChance
end
expect(math.abs(totalChance - EconomyConfig.MachineRollChanceTotal) < 0.000001, "machine chances must total the configured percentage")
for _, definition in ipairs(rollPool) do
	local chance = definition.RollChance :: number
	local odds = EconomyRules.getMachineOddsLabel(definition.Id, rollPool)
	expect(odds ~= nil and string.sub(odds, 1, 2) == "1/", "every rollable machine must have an odds label")
	expect(definition.Rarity == EconomyRules.getRarityFromOdds(EconomyConfig.MachineRollChanceTotal / chance), "each machine rarity must follow its weighted chance")
end
local baseTotalChance = EconomyRules.getRollPoolTotalChance(rollPool)
expect(math.abs(baseTotalChance - EconomyConfig.MachineRollChanceTotal) < 0.000001, "base chance total should remain configured")
local luckyPool = EconomyRules.getLuckAdjustedRollPool(rollPool, 2)
expect(EconomyRules.getRollPoolTotalChance(luckyPool) > baseTotalChance, "Luck should raise higher-rarity weights")
local rarestMachineId = nil
local rarestBaseDenominator = 0
for _, definition in ipairs(rollPool) do
	local denominator = EconomyRules.getMachineOddsDenominator(definition.Id, rollPool) or 0
	if denominator > rarestBaseDenominator then rarestMachineId = definition.Id; rarestBaseDenominator = denominator end
end
local luckyDenominator = EconomyRules.getMachineOddsDenominator(rarestMachineId, luckyPool)
expect(luckyDenominator and luckyDenominator < rarestBaseDenominator, "Luck should improve the rarest configured odds")
expect(EconomyRules.getMachineOddsDenominator(rarestMachineId, rollPool) == rarestBaseDenominator, "lucky weights must not mutate base definitions")
expect(EconomyRules.getRollPoolTotalChance(EconomyRules.getLuckAdjustedRollPool(rollPool, 1)) == baseTotalChance, "inactive Luck should preserve base weights")

local boostersValid, boostersError = BoosterRules.validate()
expect(boostersValid, boostersError or "booster config should validate")
local boosterInventory = BoosterRules.sanitizeInventory({ Coin = 999, Luck = 2, Unknown = 10, Negative = -1 })
expect(boosterInventory.Coin == BoosterConfig.MaxStoredPerType and boosterInventory.Luck == 2, "stored booster counts should be bounded")
expect(boosterInventory.Unknown == nil and boosterInventory.Negative == nil, "unknown and invalid booster counts should be removed")
local totalBoosterWeight = BoosterRules.getTotalSpawnWeight()
expect(totalBoosterWeight >= 100, "starter booster weights should remain positive and extensible")
expect(BoosterRules.pickBoosterId(0) == "Coin", "the first booster weight should resolve to the Coin multiplier")
expect(BoosterRules.pickBoosterId(69.99) == "Coin", "Coin multiplier booster weight boundary is incorrect")
expect(BoosterRules.pickBoosterId(70) == "Luck", "Luck should start at its configured weight")
expect(BoosterRules.pickBoosterId(99.99) == "Luck", "Luck booster range boundary is incorrect")
expect(BoosterRules.pickBoosterId(totalBoosterWeight) == nil, "out-of-range booster rolls should fail")
local coinBooster = assert(BoosterRules.get("Coin"))
local luckBooster = assert(BoosterRules.get("Luck"))
expect(coinBooster.Effect.Kind == "SaleValue" and coinBooster.Effect.Multiplier == 2, "Coin pickup should boost sale value rather than grant fixed Coins")
expect(coinBooster.Effect.DurationSeconds == 30, "Coin multiplier duration should remain config-driven")
expect(luckBooster.Effect.DurationSeconds == 30, "Luck duration should remain config-driven")
expect(BoosterConfig.MaxLuckDurationSeconds <= 120, "temporary Luck duration should remain capped")
expect(BoosterConfig.LandRaycast.Distance > BoosterConfig.LandRaycast.StartHeight, "booster land ray must reach below the plot")
expect(BoosterConfig.LandRaycast.PositionAttempts > 0 and BoosterConfig.LandRaycast.MinimumGroundNormalY > 0, "booster land search must use bounded surface checks")
expect(BoosterConfig.Fall.DurationSeconds > 0 and BoosterConfig.Fall.LandedSize > 0, "booster fall animation must have valid timing and size")
expect(BoosterConfig.Fall.LandingHeight >= BoosterConfig.Fall.LandedSize / 2, "booster should settle on top of a surface")

local goldenizer = assert(MachineDefinitions.get("Goldenizer"))
expect(goldenizer.Rarity == "Uncommon", "a machine at the inclusive 1/500 boundary should be Uncommon")
local definitionsValid, definitionsError = MachineDefinitions.validate()
expect(definitionsValid, definitionsError or "per-machine chance definitions should validate")
local samplePool = {
	{ Id = "A", Rollable = true, RollChance = 25 },
	{ Id = "B", Rollable = true, RollChance = 75 },
}
expect(EconomyRules.getMachineOddsLabel("A", samplePool) == "1/4", "weighted odds label should use the pool total")
expect(EconomyRules.getMachineOddsLabel("B", samplePool) == "1/1.3", "weighted odds label should describe the individual machine chance")
expect(EconomyRules.pickMachineId(samplePool, 0) == "A", "weighted selection should choose the first machine")
expect(EconomyRules.pickMachineId(samplePool, 24.99) == "A", "first machine chance boundary is incorrect")
expect(EconomyRules.pickMachineId(samplePool, 25) == "B", "second machine chance boundary is incorrect")
expect(EconomyRules.pickMachineId(samplePool, 99.99) == "B", "second machine chance range is incorrect")
expect(EconomyRules.pickMachineId(samplePool, 100) == nil, "out-of-range machine roll should fail")

local invalidRoll = EconomyRules.getRollCost(-1)
expect(not invalidRoll, "negative roll counts must be rejected")
expect(EconomyRules.getRollCooldownRemaining(13, 10) == 3, "server cooldown should report remaining time")
expect(EconomyRules.getRollCooldownRemaining(13, 15) == 0, "expired cooldown should be ready")
local canRoll = EconomyRules.canRoll(13, 15, 0)
expect(canRoll, "free roll should be available after cooldown")
local blockedCooldown = EconomyRules.canRoll(13, 11, 0)
expect(not blockedCooldown, "server cooldown should reject early rolls")
local blockedInventory = EconomyRules.canRoll(13, 15, 200)
expect(not blockedInventory, "full inventory should reject rolls")

local firstCapacityCost = EconomyRules.getCapacityCost(1)
local secondCapacityCost = EconomyRules.getCapacityCost(2)
local maxCapacityCost = EconomyRules.getCapacityCost(3)
expect(firstCapacityCost == 25, "first capacity expansion cost is incorrect")
expect(secondCapacityCost == 100, "second capacity expansion cost is incorrect")
expect(not maxCapacityCost, "maximum capacity must not have another upgrade")

expect(EconomyRules.getResaleValue("Common") == 0, "free rolls must not mint Coins through resale")

print("Phase 3 economy tests passed")
