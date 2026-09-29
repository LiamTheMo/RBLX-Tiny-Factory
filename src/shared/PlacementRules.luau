--!strict

local MachineDefinitions
local FactoryLayout
if script ~= nil then
	MachineDefinitions = require(script.Parent.MachineDefinitions)
	FactoryLayout = require(script.Parent.FactoryLayout)
else
	MachineDefinitions = require("./MachineDefinitions")
	FactoryLayout = require("./FactoryLayout")
end

local PlacementRules = {}

local function slotCategory(slotIndex: number): string
	if slotIndex == 1 then
		return "Producer"
	elseif slotIndex == FactoryLayout.SellerSlotIndex then
		return "Seller"
	end
	return "Processor"
end

function PlacementRules.validateSlotIndex(slotIndex: any): (boolean, string?)
	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then
		return false, "Slot index must be an integer"
	end
	if slotIndex < 1 or slotIndex > FactoryLayout.SlotCount then
		return false, "Slot index is outside the factory"
	end
	return true
end

function PlacementRules.validateMachineForSlot(machineId: any, slotIndex: any): (boolean, string?)
	local slotValid, slotError = PlacementRules.validateSlotIndex(slotIndex)
	if not slotValid then
		return false, slotError
	end
	if type(machineId) ~= "string" then
		return false, "Machine ID must be text"
	end

	local definition = MachineDefinitions.get(machineId)
	if not definition then
		return false, "Unknown machine"
	end
	if definition.Category ~= slotCategory(slotIndex) then
		return false, "Machine category cannot occupy this slot"
	end
	return true
end

function PlacementRules.isSlotUnlocked(slotIndex: any, capacity: any): (boolean, string?)
	local valid, errorMessage = PlacementRules.validateSlotIndex(slotIndex)
	if not valid then
		return false, errorMessage
	end
	if type(capacity) ~= "number" or capacity < 1 or capacity % 1 ~= 0 then
		return false, "Capacity is invalid"
	end
	if slotIndex > 1 and slotIndex < FactoryLayout.SellerSlotIndex and slotIndex > capacity + 1 then
		return false, "Slot is locked by factory capacity"
	end
	return true
end

function PlacementRules.validateLayout(layout: FactoryLayout.Layout, capacity: number?): (boolean, string?)
	if type(layout) ~= "table" then
		return false, "Layout must be a table"
	end
	for slotIndex = 1, FactoryLayout.SlotCount do
		local machineId = layout[slotIndex]
		if machineId ~= nil then
			if capacity then
				local unlocked, unlockError = PlacementRules.isSlotUnlocked(slotIndex, capacity)
				if not unlocked then
					return false, unlockError
				end
			end
			local valid, errorMessage = PlacementRules.validateMachineForSlot(machineId, slotIndex)
			if not valid then
				return false, errorMessage
			end
		end
	end

	if not layout[1] or not layout[FactoryLayout.SlotCount] then
		return false, "A producer and seller are required"
	end
	return true
end

return PlacementRules
