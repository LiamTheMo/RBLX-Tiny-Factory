--!strict

local FactoryLayout = {}

export type Layout = { string? }

FactoryLayout.SlotCount = 4
FactoryLayout.EditableSlotCount = FactoryLayout.SlotCount

function FactoryLayout.isEditableMachineSlot(slotIndex: any): boolean
	return type(slotIndex) == "number"
		and slotIndex % 1 == 0
		and slotIndex >= 1
		and slotIndex <= FactoryLayout.SlotCount
end
FactoryLayout.Default = { "BasicDropper", "ValueMultiplier", nil, "Seller" }

function FactoryLayout.copy(layout: Layout): Layout
	local result: Layout = {}
	for index = 1, FactoryLayout.SlotCount do
		result[index] = layout[index]
	end
	return result
end

function FactoryLayout.toRoute(layout: Layout): { string }
	local route = {}
	for index = 1, FactoryLayout.SlotCount do
		local machineId = layout[index]
		if machineId then
			table.insert(route, machineId)
		end
	end
	return route
end

return FactoryLayout
