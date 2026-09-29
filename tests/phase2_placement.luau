--!strict

local FactoryLayout = require("../src/shared/FactoryLayout")
local PlacementRules = require("../src/shared/PlacementRules")
local MachineDefinitions = require("../src/shared/MachineDefinitions")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

expect(FactoryLayout.SlotCount == 5, "the proof-of-concept conveyor should expose five factory areas")
expect(FactoryLayout.EditableSlotCount == 5, "every factory area should be editable")
for slotIndex = 1, FactoryLayout.EditableSlotCount do
	expect(FactoryLayout.isEditableMachineSlot(slotIndex), "each factory area should be clickable")
end
expect(not FactoryLayout.isEditableMachineSlot(6), "out-of-range factory areas must not be editable")

local seller = assert(MachineDefinitions.get("Seller"))
expect(seller.Rollable and seller.Category == "Seller", "Seller should be a rollable terminal machine")

local defaultLayout = FactoryLayout.copy(FactoryLayout.Default)
local valid, errorMessage = PlacementRules.validateLayout(defaultLayout, 1)
expect(valid, errorMessage or "default layout should be valid")
expect(defaultLayout[FactoryLayout.SlotCount] == "Seller", "the saved default seller should remain compatible")

local emptyProcessor = { "BasicDropper", nil, nil, nil, "Seller" }
local emptyValid, emptyError = PlacementRules.validateLayout(emptyProcessor, 1)
expect(emptyValid, emptyError or "an empty processor slot should be valid")
expect(#FactoryLayout.toRoute(emptyProcessor) == 2, "empty slots must be removed from the logical route")

local sellerMoved, sellerMoveError = PlacementRules.createMoveLayout(defaultLayout, 5, 3, 1)
expect(sellerMoved ~= nil, sellerMoveError or "seller should move to another valid route end")
expect(sellerMoved[3] == "Seller" and sellerMoved[5] == nil, "seller should no longer be fixed to area five")
local movedValid, movedError = PlacementRules.validateLayout(sellerMoved, 1)
expect(movedValid, movedError or "a moved seller should keep the layout valid")

local sellerPlaced, sellerPlaceError = PlacementRules.createPlacementLayout(defaultLayout, "Seller", 3, 1)
expect(sellerPlaced ~= nil, sellerPlaceError or "a rolled seller should be placeable at a valid route end")
expect(sellerPlaced[3] == "Seller" and sellerPlaced[5] == nil, "placing a seller should move the existing seller")
expect(PlacementRules.isSlotUnlocked(5, 1, "Seller"), "the terminal seller should not require an extra processor capacity slot")
local processorUnlocked = PlacementRules.isSlotUnlocked(3, 1, "ValueMultiplier")
expect(not processorUnlocked, "ordinary processors should remain gated by capacity")

local invalidCategory = { "ValueMultiplier", nil, nil, nil, "Seller" }
local categoryValid = PlacementRules.validateLayout(invalidCategory)
expect(not categoryValid, "processors cannot occupy the producer area")

local processorAfterSeller = { "BasicDropper", nil, "Seller", "ValueMultiplier", nil }
local sellerValid = PlacementRules.validateLayout(processorAfterSeller)
expect(not sellerValid, "the seller must remain the last occupied machine")

local duplicateSeller = { "BasicDropper", "Seller", nil, nil, "Seller" }
local duplicateValid = PlacementRules.validateLayout(duplicateSeller)
expect(not duplicateValid, "the route must contain exactly one seller")

local noSeller = { "BasicDropper", "ValueMultiplier", nil, nil, nil }
local noSellerValid = PlacementRules.validateLayout(noSeller)
expect(not noSellerValid, "the route must retain one terminal seller")

local removedProcessor, removeError = PlacementRules.createRemoveLayout(defaultLayout, 2, 1)
expect(removedProcessor ~= nil, removeError or "processor should return to inventory")
expect(removedProcessor[2] == nil and removedProcessor[5] == "Seller", "removal should preserve producer and seller")
local removedSeller = PlacementRules.createRemoveLayout(defaultLayout, 5, 1)
expect(removedSeller == nil, "the required seller cannot be removed")

local invalidIndex = PlacementRules.validateSlotIndex(6)
expect(not invalidIndex, "out-of-range slots must be rejected")

print("Phase 2 placement tests passed")
