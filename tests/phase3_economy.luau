--!strict

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
local expectedOdds = {
	ValueMultiplier = "1/3.3",
	Giantifier = "1/4.5",
	PaintMachine = "1/5.6",
	CooldownTuner = "1/6.7",
	FastDropper = "1/20",
	CompoundPress = "1/25",
	ConveyorBooster = "1/28.6",
	HeavyDropper = "1/66.7",
	Duplicator = "1/142.9",
	Goldenizer = "1/500",
	LuckyModifier = "1/1000",
}
for machineId, odds in pairs(expectedOdds) do
	expect(EconomyRules.getMachineOddsLabel(machineId, rollPool) == odds, `{machineId} machine odds are incorrect`)
	local definition = MachineDefinitions.get(machineId)
	assert(definition, `{machineId} definition is missing`)
	local denominator = 100 / (definition.RollChance :: number)
	expect(definition.Rarity == EconomyRules.getRarityFromOdds(denominator), `{machineId} rarity does not follow its chance`)
end
expect(EconomyRules.getRarityFromOdds(1) == "Common", "1/1 should be Common")
expect(EconomyRules.getRarityFromOdds(10) == "Common", "1/10 should be Common")
expect(EconomyRules.getRarityFromOdds(10.01) == "Uncommon", "odds above 1/10 should be Uncommon")
expect(EconomyRules.getRarityFromOdds(30) == "Uncommon", "1/30 should be Uncommon")
expect(EconomyRules.getRarityFromOdds(30.01) == "Rare", "odds above 1/30 should be Rare")
expect(EconomyRules.getRarityFromOdds(100) == "Rare", "1/100 should be Rare")
expect(EconomyRules.getRarityFromOdds(100.01) == "Epic", "odds above 1/100 should be Epic")
expect(EconomyRules.getRarityFromOdds(500) == "Epic", "1/500 should be Epic")
expect(EconomyRules.getRarityFromOdds(500.01) == "Legendary", "odds above 1/500 should be Legendary")
expect(not EconomyRules.getRarityFromOdds(0), "zero denominator should not have a rarity")
expect(not EconomyRules.getMachineOddsLabel("Seller", rollPool), "non-rollable machines should not have roll odds")
local totalChance = 0
for _, definition in ipairs(rollPool) do
	totalChance += definition.RollChance
end
expect(math.abs(totalChance - 100) < 0.000001, "machine chances must total 100 percent")
local definitionsValid, definitionsError = MachineDefinitions.validate()
expect(definitionsValid, definitionsError or "per-machine chance definitions should validate")
local samplePool = {
	{ Id = "A", Rollable = true, RollChance = 25 },
	{ Id = "B", Rollable = true, RollChance = 75 },
}
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
