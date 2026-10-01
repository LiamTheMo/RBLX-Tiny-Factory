--!strict

local FactorySimulation = require("../src/shared/FactorySimulation")
local FactoryConfig = require("../src/shared/FactoryConfig")
local MachineDefinitions = require("../src/shared/MachineDefinitions")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local function confirmSellerHitboxContacts(simulation: any)
	for _, item in ipairs(simulation:getActiveItemsForDebug()) do
		if item.ReadyForSale then
			simulation:sellItem(item.Id, { AdditiveBonus = 0, Multiplier = 1 })
		end
	end
end

local valid, configurationError = FactorySimulation.validateConfiguration()
expect(valid, configurationError or "default configuration is invalid")

local definitionsValid, definitionsError = MachineDefinitions.validate()
expect(definitionsValid, definitionsError or "machine definitions are invalid")

local simulation = FactorySimulation.new({
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.25,
	MaxActiveItems = 24,
})

for _ = 1, 8 do
	simulation:step(0.25)
	confirmSellerHitboxContacts(simulation)
end

local snapshot = simulation:getSnapshot()
expect(snapshot.ProducedItems == 3, "expected three produced items after two seconds")
expect(snapshot.SoldItems == 2, "expected two items to reach the seller")
expect(snapshot.Coins == 4, "the multiplier should double each sold item value")
expect(snapshot.ProcessedItems == 2, "expected two processed items")
expect(snapshot.ActiveItems == 1, "the third item should still be in the route")

local capped = FactorySimulation.new({
	SpawnIntervalSeconds = 0.1,
	TravelTimePerSlotSeconds = 10,
	MaxActiveItems = 2,
})
capped:step(1)
local cappedSnapshot = capped:getSnapshot()
expect(cappedSnapshot.ProducedItems == 2, "active-item cap must bound produced items")
expect(cappedSnapshot.DroppedItemsAtCap > 0, "cap drops must be observable")

local invalid = FactorySimulation.validateConfiguration({ MaxActiveItems = 0 })
expect(not invalid, "zero active-item capacity must be rejected")
local invalidType = FactorySimulation.validateConfiguration({ SpawnIntervalSeconds = "fast" :: any })
expect(not invalidType, "non-numeric timing must be rejected")

local firstFactory = FactorySimulation.new()
local secondFactory = FactorySimulation.new()
firstFactory:step(FactoryConfig.TravelTimePerSlotSeconds * 3 + 1)
confirmSellerHitboxContacts(firstFactory)
secondFactory:step(0.5)
confirmSellerHitboxContacts(secondFactory)
local firstSnapshot = firstFactory:getSnapshot()
local secondSnapshot = secondFactory:getSnapshot()
expect(firstSnapshot.Coins ~= secondSnapshot.Coins, "factories must simulate independently")
expect(secondSnapshot.Coins == 0, "a factory must not receive another factory's Coins")

print("Phase 1 simulation tests passed")
