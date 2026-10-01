--!strict

local Config, Visuals, Layout
if script ~= nil then
	Config = require(script.Parent.FactoryConfig)
	Visuals = require(script.Parent.MachineVisualConfig)
	Layout = require(script.Parent.FactoryLayout)
else
	Config = require("./FactoryConfig")
	Visuals = require("./MachineVisualConfig")
	Layout = require("./FactoryLayout")
end

local Geometry = {}

function Geometry.machineLift(): number
	local belt = Visuals.Conveyor
	return belt.DeckCenterY + belt.Elevation + belt.DeckThickness / 2 - Visuals.MachineProfileBaseDeckTop
end

function Geometry.physicalSlot(layout: { string? }, routeIndex: number): number
	local current = 0
	for slot = 1, Layout.SlotCount do
		if layout[slot] then
			current += 1
			if current == routeIndex then return slot end
		end
	end
	return 1
end

function Geometry.itemPosition(layout: { string? }, item: any): (number, number, number)
	local belt, cube = Visuals.Conveyor, Visuals.ConveyorItem
	local size = cube.Size * math.clamp(item.SizeScale or 1, 0.5, 4)
	local slot = if item.ReadyForSale then Layout.SellerSlotIndex else Geometry.physicalSlot(layout, item.SlotIndex)
	local nextSlot = Geometry.physicalSlot(layout, item.SlotIndex + 1)
	local progress = 1 - math.clamp(item.TimeRemaining / Config.TravelTimePerSlotSeconds, 0, 1)
	local distance = if item.ReadyForSale then 0 elseif nextSlot > slot then (nextSlot - slot) * Visuals.SlotPitch else Visuals.SlotPitch
	local x = (slot - 1) * Visuals.SlotPitch
	local landing = math.max(belt.DeckCenterY + belt.DeckThickness / 2, belt.RollerCenterY + belt.RollerDiameter / 2)
		+ belt.Elevation + size / 2 + cube.LandingClearance
	local y = landing
	if item.SlotIndex == 1 then
		local fallFraction = math.clamp(cube.DropDurationSeconds / Config.TravelTimePerSlotSeconds, 0.05, 0.9)
		local fall = math.clamp(progress / fallFraction, 0, 1)
		local easedFall = fall * fall * (3 - 2 * fall)
		y = cube.DropStartHeight + belt.Elevation + (landing - cube.DropStartHeight - belt.Elevation) * easedFall
		if progress > fallFraction then x += ((progress - fallFraction) / (1 - fallFraction)) * distance end
	else
		x += progress * distance
	end
	return x, y, size
end

function Geometry.overlapsBox(dx: number, dy: number, dz: number, boxX: number, boxY: number, boxZ: number, cubeSize: number): boolean
	return math.abs(dx) <= (boxX + cubeSize) / 2
		and math.abs(dy) <= (boxY + cubeSize) / 2
		and math.abs(dz) <= (boxZ + cubeSize) / 2
end

return Geometry
