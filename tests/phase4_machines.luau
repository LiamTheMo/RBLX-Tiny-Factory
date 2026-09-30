--!strict

local FactorySimulation = require("../src/shared/FactorySimulation")
local MachineDefinitions = require("../src/shared/MachineDefinitions")
local CubeTypeDefinitions = require("../src/shared/CubeTypeDefinitions")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local definitionsValid, definitionsError = MachineDefinitions.validate()
expect(definitionsValid, definitionsError or "launch machine definitions should validate")
expect(#MachineDefinitions.getRollPool() >= 10, "the launch roll pool should contain varied machines")

local valueChain = FactorySimulation.new({
	Route = { "BasicDropper", "Giantifier", "Goldenizer", "Seller" },
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.1,
})
valueChain:step(0.4)
for _ = 1, 10 do valueChain:step(0.1) end
local valueSnapshot = valueChain:getSnapshot()
expect(valueSnapshot.SoldItems == 1, "the value chain should sell its first item")
expect(valueSnapshot.Coins == 10, "goldenizer should double the standard cube's five-coin value")

local duplicateChain = FactorySimulation.new({
	Route = { "BasicDropper", "Duplicator", "Seller" },
	SpawnIntervalSeconds = 10,
	TravelTimePerSlotSeconds = 0.1,
	MaxActiveItems = 4,
})
duplicateChain:step(0.3)
for _ = 1, 20 do duplicateChain:step(0.1) end
local duplicateSnapshot = duplicateChain:getSnapshot()
expect(duplicateSnapshot.SoldItems == 2, "the original and bounded duplicate should sell")
expect(duplicateSnapshot.ActiveItems == 0, "both items should leave the factory after sale")

local luckyChain = FactorySimulation.new({
	Route = { "BasicDropper", "LuckyModifier", "Seller" },
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.1,
})
luckyChain:step(0.3)
for _ = 1, 10 do luckyChain:step(0.1) end
local luckySnapshot = luckyChain:getSnapshot()
expect(luckySnapshot.SoldItems == 1 and luckySnapshot.Coins >= 1, "lucky modifier must remain bounded and valid")

local wetChain = FactorySimulation.new({
	Route = { "Raincatcher", "RainRinse", "Seller" },
	SpawnIntervalSeconds = 10,
	TravelTimePerSlotSeconds = 0.1,
})
wetChain:step(0.3)
wetChain:step(1)
expect(math.abs(wetChain:getSnapshot().Coins - 6.9) < 1e-8, "Wet cubes should receive both their type multiplier and matching upgrader")

local mismatchChain = FactorySimulation.new({
	Route = { "IslandStarter", "RainRinse", "Seller" },
	SpawnIntervalSeconds = 10,
	TravelTimePerSlotSeconds = 0.1,
})
mismatchChain:step(0.3)
mismatchChain:step(1)
expect(mismatchChain:getSnapshot().Coins == 5, "a type-specific upgrader must not affect unsupported cube types")

local premiumChain = FactorySimulation.new({
	Route = { "PrismBloom", "Goldenizer", "CompoundPress", "PremiumAppraiser" },
	SpawnIntervalSeconds = 10,
	TravelTimePerSlotSeconds = 0.1,
})
premiumChain:step(0.4)
premiumChain:step(1.25)
expect(premiumChain:getSnapshot().Coins == 43.13, "premium seller should apply its conditional payout to eligible cubes")

local cappedPayoutChain = FactorySimulation.new({
	Route = { "PrismBloom", "RainbowRefractor", "RainbowExchange" },
	SpawnIntervalSeconds = 10,
	TravelTimePerSlotSeconds = 0.1,
	MaxItemValue = 10,
})
cappedPayoutChain:step(0.4)
cappedPayoutChain:step(2)
expect(cappedPayoutChain:getSnapshot().Coins == 10, "seller bonuses must not bypass the configured currency cap")

local luckySellerChain = FactorySimulation.new({
	Route = { "BasicDropper", "LuckyTill" },
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.1,
})
luckySellerChain:step(7.1)
for _ = 1, 120 do luckySellerChain:step(0.1) end
expect(luckySellerChain:getSnapshot().SoldItems == 8, "lucky seller should process its bounded item batch")
expect(luckySellerChain:getSnapshot().Coins == 42.5, "lucky seller should grant its configured one-in-eight payout bonus")

for _, typeId in ipairs({ "Standard", "Wet", "Air", "Fire", "Lightning", "Nature", "Ice", "Earth", "Metal", "Light", "Shadow", "Time", "Crystal", "Rainbow" }) do
	expect(CubeTypeDefinitions.get(typeId) ~= nil, `cube type {typeId} must be defined`)
end

print("Phase 4 machine tests passed")
