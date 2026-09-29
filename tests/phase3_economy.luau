--!strict

local EconomyConfig = require("../src/shared/EconomyConfig")
local EconomyRules = require("../src/shared/EconomyRules")
local MachineDefinitions = require("../src/shared/MachineDefinitions")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local firstRollCost = EconomyRules.getRollCost(0)
local secondRollCost = EconomyRules.getRollCost(1)
expect(firstRollCost == 0, "the first roll should be free")
expect(secondRollCost == 0, "every roll should be free")

local rollPool = MachineDefinitions.getRollPool()
local rarityBands = EconomyConfig.RarityOddsBands
local seenRarities: { [string]: boolean } = {}
local previousMaxDenominator = 0
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
	for _, channel in ipairs(color) do
		expect(type(channel) == "number" and channel % 1 == 0 and channel >= 0 and channel <= 255, "rarity display colors must use RGB channels from 0 to 255")
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
expect(not EconomyRules.getMachineOddsLabel("Seller", rollPool), "non-rollable machines should not have roll odds")
local totalChance = 0
for _, definition in ipairs(rollPool) do
	totalChance += definition.RollChance
end
expect(math.abs(totalChance - EconomyConfig.MachineRollChanceTotal) < 0.000001, "machine chances must total the configured percentage")
for _, definition in ipairs(rollPool) do
	local chance = definition.RollChance :: number
	local odds = EconomyRules.getMachineOddsLabel(definition.Id, rollPool)
	expect(odds ~= nil and string.sub(odds, 1, 2) == "1/", "every rollable machine must have an odds label")
	expect(definition.Rarity == EconomyRules.getRarityFromOdds(totalChance / chance), "each machine rarity must follow its weighted chance")
end
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
