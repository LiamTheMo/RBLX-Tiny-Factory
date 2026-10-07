--!strict
local Definitions = require("../src/shared/MachineDefinitions")
local Simulation = require("../src/shared/FactorySimulation")
local Rules = require("../src/shared/EconomyRules")
local Config = require("../src/shared/EconomyConfig")
local function expect(condition: boolean, message: string)
	assert(condition, message)
end
expect(Definitions.validate(), "MVP definitions must validate")
local pool = Definitions.getRollPool()
local probability = 0
for rarity in pairs(Config.RarityWeights) do
	local producers, sellers = 0, 0
	for _, definition in ipairs(Definitions.getRollPool(rarity)) do
		if definition.Category == "Producer" then producers += 1 end
		if definition.Category == "Seller" then sellers += 1 end
	end
	expect(producers == 8 and sellers == 8, `Expected eight droppers and eight sellers in {rarity}; got {producers}/{sellers}`)
end
for _, definition in ipairs(pool) do
	local odds = assert(Rules.getMachineOddsDenominator(definition.Id, pool))
	expect(odds > 1 and odds < math.huge, `Invalid odds for {definition.Id}`)
	probability += 1 / odds
	if definition.Category == "Producer" or definition.Category == "Seller" then
		local route = if definition.Category == "Producer" then { definition.Id, "ValueMultiplier", "Seller" } else { "IslandStarter", "ValueMultiplier", definition.Id }
		local sim = Simulation.new({ Route = route, TravelTimePerSlotSeconds = 0.1 })
		for _ = 1, 120 do
			sim:step(0.1)
			for _, item in ipairs(sim:getActiveItemsForDebug()) do
				if item.ReadyForSale then sim:sellItem(item.Id) end
			end
		end
		local snapshot = sim:getSnapshot()
		expect(snapshot.SoldItems > 0 and snapshot.Coins > 0, `Machine {definition.Id} must complete production and sale`)
		expect(snapshot.ActiveItems <= 24, `Machine {definition.Id} exceeded item cap`)
	end
end
expect(math.abs(probability - 1) < 0.000001, "Catalog whole-roll chances must sum to one")
local sim = Simulation.new({ Route = { "IslandStarter", "ValueMultiplier", "QuickCountCounter" }, SpawnIntervalSeconds = 0.1, TravelTimePerSlotSeconds = 0.1 })
sim:step(0.5)
local ready = {}
for _, item in ipairs(sim:getActiveItemsForDebug()) do
	if item.ReadyForSale then table.insert(ready, item.Id) end
end
expect(#ready >= 2, "Cooldown regression needs queued cubes")
expect(sim:sellItem(ready[1]), "First sale should succeed immediately")
local before = sim:getSnapshot()
expect(not sim:sellItem(ready[2]), "Seller must reject a sale inside its cooldown")
expect(sim:getSnapshot().ActiveItems == before.ActiveItems and sim:getSnapshot().Coins == before.Coins, "Rejected sale must preserve cube and wallet")
sim:step(0.49)
expect(not sim:sellItem(ready[2]), "Seller must enforce the full configured interval")
sim:step(0.01)
expect(sim:sellItem(ready[2]), "Queued cube must sell at cooldown boundary")
expect(not sim:sellItem(ready[2]), "Retry must never double-credit a sale")
print("MVP catalog and seller throughput tests passed")
