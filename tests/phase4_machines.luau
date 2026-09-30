--!strict

local FactorySimulation = require("../src/shared/FactorySimulation")
local MachineDefinitions = require("../src/shared/MachineDefinitions")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local function sellReadyItems(simulation: any, buffModifiers: any?)
	for _, item in ipairs(simulation:getActiveItemsForDebug()) do
		if item.ReadyForSale then
			simulation:sellItem(item.Id, buffModifiers or { AdditiveBonus = 0, Multiplier = 1 })
		end
	end
end

local definitionsValid, definitionsError = MachineDefinitions.validate()
expect(definitionsValid, definitionsError or "launch machine definitions should validate")
expect(#MachineDefinitions.getRollPool() >= 10, "the launch roll pool should contain varied machines")

local basicDropper = assert(MachineDefinitions.get("BasicDropper"))
local seller = assert(MachineDefinitions.get("Seller"))
local originalTypeModifiers = basicDropper.TypeModifiers
local originalSellerModifiers = seller.SaleModifiers
basicDropper.TypeModifiers = { AdditiveBonus = 1, Multiplier = 1.5 }
seller.SaleModifiers = { AdditiveBonus = 4, Multiplier = 1.25 }
local layeredChain = FactorySimulation.new({
	Route = { "BasicDropper", "ValueMultiplier", "Seller" },
	SpawnIntervalSeconds = 10,
	TravelTimePerSlotSeconds = 0.1,
})
layeredChain:step(0.3)
local waitingForContact = layeredChain:getActiveItemsForDebug()[1]
expect(waitingForContact and waitingForContact.ReadyForSale, "item should wait at the Seller for a hitbox contact")
expect(layeredChain:getSnapshot().Coins == 0 and layeredChain:getSnapshot().SoldItems == 0, "reaching the Seller without hitbox contact must not award Coins")
local sold, credited = layeredChain:sellItem(waitingForContact.Id, { AdditiveBonus = 3, Multiplier = 2 })
expect(sold and credited == 37, "type, buff, processor, and Seller modifiers should determine the sale payout")
expect(not layeredChain:sellItem(waitingForContact.Id, { AdditiveBonus = 3, Multiplier = 2 }), "a cube must not be credited twice")
local layeredSnapshot = layeredChain:getSnapshot()
expect(layeredSnapshot.Coins == 37 and layeredSnapshot.TotalValueSold == 37 and layeredSnapshot.SoldItems == 1, "sale stats should match the credited currency")
basicDropper.TypeModifiers = originalTypeModifiers
seller.SaleModifiers = originalSellerModifiers

local valueChain = FactorySimulation.new({
	Route = { "BasicDropper", "Giantifier", "Goldenizer", "Seller" },
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.1,
})
valueChain:step(0.4)
sellReadyItems(valueChain)
local valueSnapshot = valueChain:getSnapshot()
expect(valueSnapshot.SoldItems == 1, "the value chain should sell its first item")
expect(valueSnapshot.Coins == 2, "goldenizer should provide a bounded value multiplier")

local duplicateChain = FactorySimulation.new({
	Route = { "BasicDropper", "Duplicator", "Seller" },
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.1,
	MaxActiveItems = 4,
})
duplicateChain:step(0.3)
sellReadyItems(duplicateChain)
local duplicateSnapshot = duplicateChain:getSnapshot()
expect(duplicateSnapshot.SoldItems == 1, "the original duplicated item should sell")
expect(duplicateSnapshot.ActiveItems == 1, "the duplicate should remain bounded and active")
duplicateChain:step(0.2)
sellReadyItems(duplicateChain)
expect(duplicateChain:getSnapshot().SoldItems == 2, "the duplicate should eventually sell")

local luckyChain = FactorySimulation.new({
	Route = { "BasicDropper", "LuckyModifier", "Seller" },
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.1,
})
luckyChain:step(0.3)
sellReadyItems(luckyChain)
local luckySnapshot = luckyChain:getSnapshot()
expect(luckySnapshot.SoldItems == 1 and luckySnapshot.Coins >= 1, "lucky modifier must remain bounded and valid")

print("Phase 4 machine tests passed")
