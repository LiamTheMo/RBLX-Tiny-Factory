--!strict

local FactorySimulation = require("../src/shared/FactorySimulation")
local MachineDefinitions = require("../src/shared/MachineDefinitions")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local valid, configurationError = FactorySimulation.validateConfiguration()
expect(valid, configurationError or "default configuration is invalid")

local eventProbe = FactorySimulation.new({ SpawnIntervalSeconds = 1 })
local producedOnStep, soldOnStep = eventProbe:step(0.25)
expect(producedOnStep and not soldOnStep, "step should report production without allocating snapshots")
expect(eventProbe:getCoins() == 0, "direct coin reads should match initial simulation state")

local definitionsValid, definitionsError = MachineDefinitions.validate()
expect(definitionsValid, definitionsError or "machine definitions are invalid")

local simulation = FactorySimulation.new({
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.25,
	MaxActiveItems = 24,
})

for _ = 1, 12 do
	simulation:step(0.25)
end

local snapshot = simulation:getSnapshot()
expect(snapshot.ProducedItems == 4, "expected four produced items after three seconds")
expect(snapshot.SoldItems == 2, "expected two items to complete the seller's processing cycle")
expect(snapshot.Coins == 20, "the multiplier should double each five-coin standard item")
expect(snapshot.ProcessedItems == 3, "items should be counted when they pass through the processor")
expect(snapshot.ActiveItems == 2, "the next item and an item at the seller should remain active")

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
for _ = 1, 12 do firstFactory:step(0.25) end
secondFactory:step(0.5)
local firstSnapshot = firstFactory:getSnapshot()
local secondSnapshot = secondFactory:getSnapshot()
expect(firstSnapshot.Coins ~= secondSnapshot.Coins, "factories must simulate independently")
expect(secondSnapshot.Coins == 0, "a factory must not receive another factory's Coins")

print("Phase 1 simulation tests passed")
