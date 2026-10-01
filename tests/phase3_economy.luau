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
expect(layeredSale == 71.25, "sale value should add all bonuses before multiplying and cent rounding")
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
expect(not EconomyRules.shouldPlayUltraRareCutscene(10000), "the ultra-rare cutscene should not include the exact 1/10,000 boundary")
expect(EconomyRules.shouldPlayUltraRareCutscene(10000.01), "the ultra-rare cutscene should include odds rarer than 1/10,000")
local sellerDefinition = MachineDefinitions.get("Seller")
expect(sellerDefinition ~= nil and sellerDefinition.Rollable, "the seller should be part of the roll pool")
local rarityTotal = EconomyRules.getTotalWeight(EconomyConfig.RarityWeights)
expect(rarityTotal > 0, "nested rarity weights must have positive total weight")
for _, definition in ipairs(rollPool) do
	expect(definition.RollWeight ~= nil and definition.RollWeight > 0, "every rollable machine needs an inner weight")
	expect(EconomyRules.getMachineOddsLabel(definition.Id, rollPool) ~= nil, "every machine must have a nested odds label")
	local innerTotal = EconomyRules.getRollPoolTotalChance(rollPool, definition.Rarity)
	local expectedOdds = rarityTotal * innerTotal / (EconomyConfig.RarityWeights[definition.Rarity] * definition.RollWeight)
	expect(math.abs((EconomyRules.getMachineOddsDenominator(definition.Id, rollPool) or 0) - expectedOdds) < 0.000001, "nested odds must multiply rarity and item weights")
end
local baseWeights = EconomyRules.getRollPoolTotalChance(rollPool)
expect(baseWeights > 0, "inner machine weights should have a positive total")
local luckyWeights = EconomyRules.getLuckAdjustedRarityWeights(EconomyConfig.RarityWeights, 2)
local rarestMachineId = nil
local rarestRarityWeight = math.huge
for _, definition in ipairs(rollPool) do
	local adjusted = luckyWeights[definition.Rarity] / EconomyRules.getTotalWeight(luckyWeights)
	local base = EconomyConfig.RarityWeights[definition.Rarity] / rarityTotal
	if adjusted > base and EconomyConfig.RarityWeights[definition.Rarity] < rarestRarityWeight then
		rarestMachineId = definition.Id
		rarestRarityWeight = EconomyConfig.RarityWeights[definition.Rarity]
	end
end
local luckyPool = EconomyRules.getLuckAdjustedRollPool(rollPool, 2)
expect(luckyPool[1].RollChance ~= nil, "luck-adjusted display pool should expose effective item chances")
local baseOdds = EconomyRules.getMachineOddsDenominator(rarestMachineId, rollPool)
local luckyOdds = EconomyRules.getMachineOddsDenominator(rarestMachineId, rollPool, luckyWeights)
expect(baseOdds and luckyOdds and luckyOdds < baseOdds, "Luck should improve higher-rarity odds")

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
expect(goldenizer.Rarity == "Epic", "nested machine rarity must be explicit and independent of flat odds bands")
local definitionsValid, definitionsError = MachineDefinitions.validate()
expect(definitionsValid, definitionsError or "per-machine chance definitions should validate")
local samplePool = {
	{ Id = "A", Rarity = "Common", Rollable = true, RollWeight = 1 },
	{ Id = "B", Rarity = "Common", Rollable = true, RollWeight = 3 },
}
local sampleRarities = { Common = 1 }
expect(EconomyRules.getMachineOddsDenominator("A", samplePool, sampleRarities) == 4, "nested odds should account for both weighted draws")
expect(EconomyRules.pickMachineId(samplePool, 0, "Common") == "A", "weighted selection should choose the first machine")
expect(EconomyRules.pickMachineId(samplePool, 1, "Common") == "B", "inner item weights should define the second draw")
expect(EconomyRules.pickMachineId(samplePool, 4, "Common") == nil, "out-of-range item rolls should fail")

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
