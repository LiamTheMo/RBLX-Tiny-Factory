--!strict

local FactoryLayout = require("../src/shared/FactoryLayout")
local PlacementRules = require("../src/shared/PlacementRules")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

expect(FactoryLayout.SlotCount == 5, "the temporary conveyor should have four machine slots and a seller")
expect(FactoryLayout.EditableSlotCount == 4, "four machine positions should be editable")
expect(FactoryLayout.SellerSlotIndex == 5, "the seller should remain the final position")
for slotIndex = 1, FactoryLayout.EditableSlotCount do
	expect(FactoryLayout.isEditableMachineSlot(slotIndex), "each of the first four conveyor positions should be clickable")
end
expect(not FactoryLayout.isEditableMachineSlot(FactoryLayout.SellerSlotIndex), "the fixed seller must not be editable")

local defaultLayout = FactoryLayout.copy(FactoryLayout.Default)
local valid, errorMessage = PlacementRules.validateLayout(defaultLayout)
expect(valid, errorMessage or "default layout should be valid")

local emptyProcessor = { "BasicDropper", nil, nil, nil, "Seller" }
local emptyValid, emptyError = PlacementRules.validateLayout(emptyProcessor)
expect(emptyValid, emptyError or "an empty processor slot should be valid")
expect(#FactoryLayout.toRoute(emptyProcessor) == 2, "empty slots must be removed from the logical route")

local invalidCategory = { "ValueMultiplier", nil, nil, nil, "Seller" }
local categoryValid = PlacementRules.validateLayout(invalidCategory)
expect(not categoryValid, "processors cannot occupy the producer slot")

local invalidSeller = { "BasicDropper", "Seller", nil, nil, "Seller" }
local sellerValid = PlacementRules.validateLayout(invalidSeller)
expect(not sellerValid, "seller cannot occupy a processor slot")

local invalidIndex = PlacementRules.validateSlotIndex(6)
expect(not invalidIndex, "out-of-range slots must be rejected")

print("Phase 2 placement tests passed")
