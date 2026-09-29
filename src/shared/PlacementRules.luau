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

function PlacementRules.validateSlotIndex(slotIndex: any): (boolean, string?)
	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then
		return false, "Slot index must be an integer"
	end
	if not FactoryLayout.isEditableMachineSlot(slotIndex) then
		return false, "Slot index is outside the editable factory areas"
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
	if slotIndex == 1 and definition.Category ~= "Producer" then
		return false, "The first factory area must contain a dropper"
	end
	if slotIndex > 1 and definition.Category == "Producer" then
		return false, "Droppers must start the production route"
	end
	return true
end

function PlacementRules.isSlotUnlocked(slotIndex: any, capacity: any, machineId: any?): (boolean, string?)
	local valid, errorMessage = PlacementRules.validateSlotIndex(slotIndex)
	if not valid then
		return false, errorMessage
	end
	if type(capacity) ~= "number" or capacity < 1 or capacity % 1 ~= 0 then
		return false, "Capacity is invalid"
	end
	local definition = if type(machineId) == "string" then MachineDefinitions.get(machineId) else nil
	if definition and definition.Category == "Seller" then
		return true
	end
	if slotIndex > capacity + 1 then
		return false, "Slot is locked by factory capacity"
	end
	return true
end

function PlacementRules.validateLayout(layout: FactoryLayout.Layout, capacity: number?): (boolean, string?)
	if type(layout) ~= "table" then
		return false, "Layout must be a table"
	end

	local producerCount = 0
	local sellerCount = 0
	local sellerSlot: number? = nil
	local lastOccupiedSlot = 0
	for slotIndex = 1, FactoryLayout.SlotCount do
		local machineId = layout[slotIndex]
		if machineId ~= nil then
			local definition = MachineDefinitions.get(machineId)
			if not definition then
				return false, "Unknown machine"
			end
			if capacity then
				local unlocked, unlockError = PlacementRules.isSlotUnlocked(slotIndex, capacity, machineId)
				if not unlocked then
					return false, unlockError
				end
			end
			local valid, errorMessage = PlacementRules.validateMachineForSlot(machineId, slotIndex)
			if not valid then
				return false, errorMessage
			end
			if definition.Category == "Producer" then
				producerCount += 1
			elseif definition.Category == "Seller" then
				sellerCount += 1
				sellerSlot = slotIndex
			end
			lastOccupiedSlot = slotIndex
		end
	end

	if producerCount ~= 1 or not layout[1] then
		return false, "A single dropper is required at the start of the route"
	end
	if sellerCount ~= 1 or sellerSlot ~= lastOccupiedSlot then
		return false, "Place one seller at the end of the production route"
	end
	return true
end

function PlacementRules.createPlacementLayout(
	layout: FactoryLayout.Layout,
	machineId: any,
	slotIndex: any,
	capacity: any
): (FactoryLayout.Layout?, string?)
	if type(layout) ~= "table" then
		return nil, "Layout must be a table"
	end
	local slotValid, slotError = PlacementRules.validateSlotIndex(slotIndex)
	if not slotValid then
		return nil, slotError
	end
	local machineValid, machineError = PlacementRules.validateMachineForSlot(machineId, slotIndex)
	if not machineValid then
		return nil, machineError
	end
	local unlocked, unlockError = PlacementRules.isSlotUnlocked(slotIndex, capacity, machineId)
	if not unlocked then
		return nil, unlockError
	end

	local candidate = FactoryLayout.copy(layout)
	local definition = MachineDefinitions.get(machineId)
	if definition and definition.Category == "Seller" then
		for otherSlot = 1, FactoryLayout.SlotCount do
			if otherSlot ~= slotIndex then
				local current = candidate[otherSlot]
				local currentDefinition = current and MachineDefinitions.get(current)
				if currentDefinition and currentDefinition.Category == "Seller" then
					candidate[otherSlot] = nil
				end
			end
		end
	end
	candidate[slotIndex] = machineId
	local valid, errorMessage = PlacementRules.validateLayout(candidate, capacity)
	if not valid then
		return nil, errorMessage
	end
	return candidate
end

function PlacementRules.createMoveLayout(
	layout: FactoryLayout.Layout,
	sourceSlotIndex: any,
	destinationSlotIndex: any,
	capacity: any
): (FactoryLayout.Layout?, string?)
	if type(layout) ~= "table" then
		return nil, "Layout must be a table"
	end
	local sourceValid, sourceError = PlacementRules.validateSlotIndex(sourceSlotIndex)
	local destinationValid, destinationError = PlacementRules.validateSlotIndex(destinationSlotIndex)
	if not sourceValid then
		return nil, sourceError
	end
	if not destinationValid then
		return nil, destinationError
	end
	if sourceSlotIndex == destinationSlotIndex then
		return nil, "Choose a different destination"
	end
	local machineId = layout[sourceSlotIndex]
	if not machineId then
		return nil, "Source slot is empty"
	end
	if layout[destinationSlotIndex] then
		return nil, "Destination slot is occupied"
	end
	local machineValid, machineError = PlacementRules.validateMachineForSlot(machineId, destinationSlotIndex)
	if not machineValid then
		return nil, machineError
	end
	local unlocked, unlockError = PlacementRules.isSlotUnlocked(destinationSlotIndex, capacity, machineId)
	if not unlocked then
		return nil, unlockError
	end

	local candidate = FactoryLayout.copy(layout)
	candidate[sourceSlotIndex] = nil
	candidate[destinationSlotIndex] = machineId
	local valid, errorMessage = PlacementRules.validateLayout(candidate, capacity)
	if not valid then
		return nil, errorMessage
	end
	return candidate
end

function PlacementRules.createRemoveLayout(
	layout: FactoryLayout.Layout,
	slotIndex: any,
	capacity: any
): (FactoryLayout.Layout?, string?)
	if type(layout) ~= "table" then
		return nil, "Layout must be a table"
	end
	local validSlot, slotError = PlacementRules.validateSlotIndex(slotIndex)
	if not validSlot then
		return nil, slotError
	end
	if not layout[slotIndex] then
		return nil, "Slot is already empty"
	end
	local candidate = FactoryLayout.copy(layout)
	candidate[slotIndex] = nil
	local valid, errorMessage = PlacementRules.validateLayout(candidate, capacity)
	if not valid then
		return nil, errorMessage
	end
	return candidate
end

return PlacementRules
