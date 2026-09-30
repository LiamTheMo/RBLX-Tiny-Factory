--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactoryConfig = require(Shared:WaitForChild("FactoryConfig"))
local MachineVisualConfig = require(Shared:WaitForChild("MachineVisualConfig"))
local FactoryLayout = require(Shared:WaitForChild("FactoryLayout"))
local FactorySimulation = require(Shared:WaitForChild("FactorySimulation"))
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local AnalyticsService = require(script.Parent.AnalyticsService)
local EffectService = require(script.Parent.EffectService)

local FactoryService = {}
local factories = {}
local lastRequestAt = {}
local started = false
local nextPlotIndex = 0
local attributeUpdateAccumulator = 0

local function copyInventory(inventory: { [string]: number }): { [string]: number }
	local result = {}
	for machineId, quantity in pairs(inventory) do
		result[machineId] = quantity
	end
	return result
end

local function layoutForClient(layout: FactoryLayout.Layout): { string }
	local result = {}
	for slotIndex = 1, FactoryLayout.SlotCount do
		result[slotIndex] = layout[slotIndex] or ""
	end
	return result
end

local function createPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addSlotClickDetector(part: BasePart, slotIndex: number)
	part:SetAttribute("FactorySlotIndex", slotIndex)
	if not FactoryLayout.isEditableMachineSlot(slotIndex) then
		return
	end
	local detector = Instance.new("ClickDetector")
	detector.Name = "FactorySlotClick"
	detector.MaxActivationDistance = 32
	detector:SetAttribute("FactorySlotIndex", slotIndex)
	detector.Parent = part
end

local function colorFromRgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function createConveyor(plot: Folder, origin: Vector3): Folder
	local conveyorConfig = MachineVisualConfig.Conveyor
	local slotPitch = MachineVisualConfig.SlotPitch
	local slotCount = FactoryLayout.SlotCount
	local segmentLength = slotPitch + conveyorConfig.SegmentOverlap
	local totalLength = (slotCount - 1) * slotPitch + segmentLength
	local centerOffsetX = (slotCount - 1) * slotPitch / 2
	local deckTop = conveyorConfig.DeckCenterY + conveyorConfig.DeckThickness / 2 + conveyorConfig.Elevation

	local conveyor = Instance.new("Folder")
	conveyor.Name = "Conveyor"
	conveyor.Parent = plot
	conveyor:SetAttribute("SlotCount", slotCount)

	local underframe = createPart(
		conveyor,
		"ConveyorUnderframe",
		Vector3.new(
			totalLength + conveyorConfig.FrameLengthPadding,
			conveyorConfig.FrameHeight,
			conveyorConfig.BeltWidth + conveyorConfig.FrameWidthPadding
		),
		origin + Vector3.new(centerOffsetX, conveyorConfig.FrameCenterY + conveyorConfig.Elevation, 0),
		colorFromRgb(conveyorConfig.FrameColor)
	)
	underframe.Material = Enum.Material.Metal

	for slotIndex = 1, slotCount do
		local offset = (slotIndex - 1) * slotPitch
		local isSellerBay = slotIndex == FactoryLayout.SellerSlotIndex
		local belt = createPart(
			conveyor,
			string.format("Conveyor_%d", slotIndex),
			Vector3.new(segmentLength, conveyorConfig.DeckThickness, conveyorConfig.BeltWidth),
			origin + Vector3.new(offset, conveyorConfig.DeckCenterY + conveyorConfig.Elevation, 0),
			colorFromRgb(if isSellerBay then conveyorConfig.SellerBay.DeckColor else conveyorConfig.DeckColor)
		)
		belt.Material = Enum.Material.Rubber
		addSlotClickDetector(belt, slotIndex)

		for rollerIndex = 1, conveyorConfig.RollerCountPerSlot do
			local rollerOffset = -slotPitch / 2 + ((rollerIndex - 0.5) * slotPitch / conveyorConfig.RollerCountPerSlot)
			local rollerPosition = origin + Vector3.new(offset + rollerOffset, conveyorConfig.RollerCenterY + conveyorConfig.Elevation, 0)
			local roller = createPart(
				conveyor,
				string.format("ConveyorRoller_%d_%d", slotIndex, rollerIndex),
				Vector3.new(
					conveyorConfig.BeltWidth + conveyorConfig.RollerOverhang,
					conveyorConfig.RollerDiameter,
					conveyorConfig.RollerDiameter
				),
				rollerPosition,
				colorFromRgb(conveyorConfig.RollerColor)
			)
			roller.Shape = Enum.PartType.Cylinder
			roller.CFrame = CFrame.new(rollerPosition) * CFrame.Angles(0, math.rad(90), 0)
			roller.Material = Enum.Material.Metal
			addSlotClickDetector(roller, slotIndex)
		end

		for sideIndex, side in ipairs({ -1, 1 }) do
			local guideOffset = side * (conveyorConfig.BeltWidth / 2 + conveyorConfig.GuideThickness / 2)
			local guidePosition = origin + Vector3.new(offset, deckTop + conveyorConfig.GuideHeight / 2, guideOffset)
			local guide = createPart(
				conveyor,
				string.format("ConveyorGuide_%d_%d", slotIndex, sideIndex),
				Vector3.new(segmentLength, conveyorConfig.GuideHeight, conveyorConfig.GuideThickness),
				guidePosition,
				colorFromRgb(conveyorConfig.GuideColor)
			)
			guide.Material = Enum.Material.Metal
			addSlotClickDetector(guide, slotIndex)

			local accent = createPart(
				conveyor,
				string.format("ConveyorGuideAccent_%d_%d", slotIndex, sideIndex),
				Vector3.new(segmentLength, conveyorConfig.GuideAccentHeight, conveyorConfig.GuideAccentThickness),
				origin + Vector3.new(
					offset,
					deckTop + conveyorConfig.GuideHeight - conveyorConfig.GuideAccentHeight / 2,
					guideOffset
				),
				colorFromRgb(if isSellerBay then conveyorConfig.SellerBay.AccentColor else conveyorConfig.GuideAccentColor)
			)
			accent.Material = Enum.Material.Neon
			addSlotClickDetector(accent, slotIndex)

			for supportIndex, supportOffset in ipairs({ -conveyorConfig.SupportOffsetX, conveyorConfig.SupportOffsetX }) do
				local support = createPart(
					conveyor,
					string.format("ConveyorSupport_%d_%d_%d", slotIndex, sideIndex, supportIndex),
					Vector3.new(conveyorConfig.SupportThickness, conveyorConfig.SupportHeight + conveyorConfig.Elevation, conveyorConfig.SupportThickness),
					origin + Vector3.new(offset + supportOffset, (conveyorConfig.SupportHeight + conveyorConfig.Elevation) / 2, guideOffset),
					colorFromRgb(conveyorConfig.SupportColor)
				)
				support.Material = Enum.Material.Metal
			end
		end

		local areaLabel = Instance.new("BillboardGui")
		areaLabel.Name = string.format("ConveyorAreaLabel_%d", slotIndex)
		areaLabel.Adornee = belt
		areaLabel.AlwaysOnTop = true
		areaLabel.MaxDistance = conveyorConfig.LabelMaxDistance
		areaLabel.Size = UDim2.fromOffset(conveyorConfig.LabelWidthPixels, conveyorConfig.LabelHeightPixels)
		areaLabel.StudsOffset = Vector3.new(0, conveyorConfig.LabelHeight, conveyorConfig.BeltWidth / 2 + conveyorConfig.GuideThickness + 0.2)
		areaLabel.Parent = belt

		local areaText = Instance.new("TextLabel")
		areaText.Name = "Label"
		areaText.BackgroundTransparency = 1
		areaText.Size = UDim2.fromScale(1, 1)
		areaText.Text = FactoryLayout.getAreaLabel(slotIndex)
		areaText.TextColor3 = colorFromRgb(if isSellerBay then conveyorConfig.SellerBay.LabelColor else conveyorConfig.LabelColor)
		areaText.TextSize = conveyorConfig.LabelTextSize
		areaText.TextStrokeColor3 = colorFromRgb(conveyorConfig.FrameColor)
		areaText.TextStrokeTransparency = 0.2
		areaText.Font = Enum.Font.GothamBold
		areaText.Parent = areaLabel
	end

	return conveyor
end

local function createPlaceholderPlot(player: Player): (Folder, Vector3, Folder)
	local plotsFolder = workspace:FindFirstChild("TinyFactoryPlots")
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "TinyFactoryPlots"
		plotsFolder.Parent = workspace
	end

	local plotConfig = MachineVisualConfig.FactoryPlot
	nextPlotIndex += 1
	local origin = Vector3.new((nextPlotIndex - 1) * plotConfig.SpacingX, 0, 0)
	local plot = Instance.new("Folder")
	plot.Name = string.format("Factory_%d", player.UserId)
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot.Parent = plotsFolder

	local slotCount = FactoryLayout.SlotCount
	local slotPitch = MachineVisualConfig.SlotPitch
	local conveyorConfig = MachineVisualConfig.Conveyor
	local segmentLength = slotPitch + conveyorConfig.SegmentOverlap
	local conveyorLength = (slotCount - 1) * slotPitch + segmentLength
	local centerOffsetX = (slotCount - 1) * slotPitch / 2
	local base = createPart(
		plot,
		"FactoryPlatform",
		Vector3.new(conveyorLength + plotConfig.BaseLengthPadding, plotConfig.BaseThickness, plotConfig.BaseWidth),
		origin + Vector3.new(centerOffsetX, plotConfig.BaseCenterY, 0),
		colorFromRgb(plotConfig.BaseColor)
	)
	base.Material = Enum.Material.WoodPlanks
	base.CanCollide = true

	local conveyor = createConveyor(plot, origin)
	return plot, origin, conveyor
end

local function updateDebugAttributes(player: Player, factory: any)
	local snapshot = factory.simulation:getSnapshot()
	player:SetAttribute("FactoryCoins", snapshot.Coins)
	player:SetAttribute("FactoryActiveItems", snapshot.ActiveItems)
	player:SetAttribute("FactoryProducedItems", snapshot.ProducedItems)
	player:SetAttribute("FactorySoldItems", snapshot.SoldItems)
	player:SetAttribute("FactoryTotalValueSold", snapshot.TotalValueSold)
	player:SetAttribute("FactoryDroppedItemsAtCap", snapshot.DroppedItemsAtCap)
	player:SetAttribute("FactoryCapacity", factory.capacity)
	player:SetAttribute("FactoryLayout", table.concat(layoutForClient(factory.layout), ","))
end

local function refreshMachineVisuals(factory: any)
	local machineFolder = factory.plot:FindFirstChild("Machines")
	if machineFolder then
		machineFolder:Destroy()
	end
	machineFolder = Instance.new("Folder")
	machineFolder.Name = "Machines"
	machineFolder.Parent = factory.plot

	for slotIndex = 1, FactoryLayout.EditableSlotCount do
		local belt = factory.conveyor:FindFirstChild(string.format("Conveyor_%d", slotIndex))
		local detector = belt and belt:FindFirstChild("FactorySlotClick")
		if detector and detector:IsA("ClickDetector") then
			detector.MaxActivationDistance = 32
		end
	end

	for slotIndex = 1, FactoryLayout.SlotCount do
		local machineId = factory.layout[slotIndex]
		if machineId then
			local definition = MachineDefinitions.get(machineId)
			if definition then
				local profileKey = definition.VisualStyle or (definition.Category == "Producer" and "Dropper") or definition.Category
				local profile = MachineVisualConfig.Profiles[profileKey] or MachineVisualConfig.Profiles.Processor
				local primaryColor = colorFromRgb(profile.PrimaryColor)
				local accentColor = colorFromRgb(profile.AccentColor)
				local machineLift = MachineVisualConfig.Conveyor.DeckCenterY + MachineVisualConfig.Conveyor.Elevation + MachineVisualConfig.Conveyor.DeckThickness / 2 - MachineVisualConfig.MachineProfileBaseDeckTop
				local basePosition = factory.origin + Vector3.new((slotIndex - 1) * MachineVisualConfig.SlotPitch, machineLift, 0)
				local model = Instance.new("Model")
				model.Name = string.format("Slot_%d_%s", slotIndex, machineId)
				model.Parent = machineFolder

				local function makePart(name: string, size: Vector3, offset: Vector3, color: Color3): Part
					local part = createPart(model, name, size, basePosition + offset, color)
					part.Material = Enum.Material.SmoothPlastic
					return part
				end

				local clickPart: Part
				if profile.Style == "Dropper" then
					makePart("DropperFoot", Vector3.new(2.8, 0.3, 2.4), Vector3.new(0, 0.32, 0), accentColor)
					makePart("DropperSupportLeft", Vector3.new(0.3, 2.2, 0.3), Vector3.new(0, 1.4, -0.86), accentColor)
					makePart("DropperSupportRight", Vector3.new(0.3, 2.2, 0.3), Vector3.new(0, 1.4, 0.86), accentColor)
					makePart("DropperHeadLeft", Vector3.new(0.62, 1.2, 1.8), Vector3.new(-0.78, 2.55, 0), primaryColor)
					makePart("DropperHeadRight", Vector3.new(0.62, 1.2, 1.8), Vector3.new(0.78, 2.55, 0), primaryColor)
					makePart("DropperNozzleLeft", Vector3.new(0.18, 0.5, 0.18), Vector3.new(-0.48, 1.65, 0), accentColor)
					makePart("DropperNozzleRight", Vector3.new(0.18, 0.5, 0.18), Vector3.new(0.48, 1.65, 0), accentColor)
					makePart("DropperNozzleNear", Vector3.new(0.18, 0.5, 0.18), Vector3.new(0, 1.65, -0.48), accentColor)
					makePart("DropperNozzleFar", Vector3.new(0.18, 0.5, 0.18), Vector3.new(0, 1.65, 0.48), accentColor)
					clickPart = makePart("DropperHousing", Vector3.new(2.2, 0.35, 2.0), Vector3.new(0, 3.25, 0), primaryColor)
				elseif profile.Style == "Seller" then
					makePart("SellerFoot", Vector3.new(2.8, 0.3, 2.4), Vector3.new(0, 0.32, 0), accentColor)
					makePart("SellerTray", Vector3.new(2.4, 0.25, 2.1), Vector3.new(0, 0.62, 0), accentColor)
					clickPart = makePart("SellerHousing", Vector3.new(1.8, 1.6, 1.7), Vector3.new(0, 1.62, 0), primaryColor)
				else
					makePart("ProcessorFoot", Vector3.new(2.8, 0.3, 2.4), Vector3.new(0, 0.32, 0), accentColor)
					clickPart = makePart("ProcessorHousing", Vector3.new(2.1, 1.5, 1.9), Vector3.new(0, 1.25, 0), primaryColor)
				end

				addSlotClickDetector(clickPart, slotIndex)
				clickPart:SetAttribute("MachineId", definition.Id)
				clickPart:SetAttribute("DisplayName", definition.DisplayName)
				clickPart:SetAttribute("Description", definition.Description)
				clickPart:SetAttribute("Rarity", definition.Rarity)
				clickPart:SetAttribute("Behavior", definition.Behavior or definition.Category)

				local labelGui = Instance.new("BillboardGui")
				labelGui.Name = "MachineLabel"
				labelGui.Adornee = clickPart
				labelGui.AlwaysOnTop = true
				labelGui.MaxDistance = 80
				labelGui.Size = UDim2.fromOffset(150, 42)
				labelGui.StudsOffset = Vector3.new(0, 1.7, 0)
				labelGui.Parent = clickPart

				local label = Instance.new("TextLabel")
				label.BackgroundColor3 = Color3.fromRGB(28, 24, 21)
				label.BackgroundTransparency = 0.2
				label.BorderSizePixel = 0
				label.Size = UDim2.fromScale(1, 1)
				label.Text = string.format("%s\n%s", definition.DisplayName, definition.Rarity)
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextSize = 11
				label.TextWrapped = true
				label.Font = Enum.Font.GothamBold
				label.Parent = labelGui
			end
		end
	end
end

local function getPhysicalSlotForRouteIndex(layout: FactoryLayout.Layout, routeIndex: number): number
	local currentRouteIndex = 0
	for slotIndex = 1, FactoryLayout.SlotCount do
		if layout[slotIndex] then
			currentRouteIndex += 1
			if currentRouteIndex == routeIndex then
				return slotIndex
			end
		end
	end
	return 1
end

local function updateVisualItems(factory: any)
	local activeItems = factory.simulation:getActiveItemsForDebug()
	local activeById = {}
	local visualConfig = MachineVisualConfig.ConveyorItem
	for _, item in ipairs(activeItems) do
		activeById[item.Id] = true
		local visual = factory.visualItems[item.Id]
		if not visual then
			visual = createPart(factory.plot, string.format("Item_%d", item.Id), Vector3.new(visualConfig.Size, visualConfig.Size, visualConfig.Size), factory.origin + Vector3.new(0, visualConfig.DropStartHeight + MachineVisualConfig.Conveyor.Elevation, 0), Color3.fromRGB(235, 235, 235))
			factory.visualItems[item.Id] = visual
		end
		local stateColors = {
			Base = Color3.fromRGB(235, 235, 235),
			Painted = Color3.fromRGB(255, 105, 160),
			Golden = Color3.fromRGB(255, 211, 66),
		}
		local size = visualConfig.Size * math.clamp(item.SizeScale or 1, 0.5, 4)
		visual.Size = Vector3.new(size, size, size)
		visual.Color = stateColors[item.VisualState] or stateColors.Base

		local physicalSlotIndex = getPhysicalSlotForRouteIndex(factory.layout, item.SlotIndex)
		local segmentProgress = 1 - math.clamp(item.TimeRemaining / FactoryConfig.TravelTimePerSlotSeconds, 0, 1)
		local x = (physicalSlotIndex - 1) * MachineVisualConfig.SlotPitch
		local nextPhysicalSlotIndex = getPhysicalSlotForRouteIndex(factory.layout, item.SlotIndex + 1)
		local travelDistance = if nextPhysicalSlotIndex > physicalSlotIndex
			then (nextPhysicalSlotIndex - physicalSlotIndex) * MachineVisualConfig.SlotPitch
			else MachineVisualConfig.SlotPitch
		local conveyorConfig = MachineVisualConfig.Conveyor
		local deckTop = conveyorConfig.DeckCenterY + conveyorConfig.DeckThickness / 2 + conveyorConfig.Elevation
		local rollerTop = conveyorConfig.RollerCenterY + conveyorConfig.RollerDiameter / 2 + conveyorConfig.Elevation
		local landingHeight = math.max(deckTop, rollerTop) + size / 2 + visualConfig.LandingClearance
		local y = landingHeight
		if item.SlotIndex == 1 then
			local fallFraction = math.clamp(visualConfig.DropDurationSeconds / FactoryConfig.TravelTimePerSlotSeconds, 0.05, 0.9)
			local fallProgress = math.clamp(segmentProgress / fallFraction, 0, 1)
			local easedFall = fallProgress * fallProgress * (3 - 2 * fallProgress)
			y = visualConfig.DropStartHeight + conveyorConfig.Elevation + (landingHeight - visualConfig.DropStartHeight - conveyorConfig.Elevation) * easedFall
			if segmentProgress > fallFraction then
				x += ((segmentProgress - fallFraction) / (1 - fallFraction)) * travelDistance
			end
		else
			x += segmentProgress * travelDistance
		end
		visual.Position = factory.origin + Vector3.new(x, y, 0)
		visual:SetAttribute("ItemValue", item.Value)
	end

	for itemId, visual in pairs(factory.visualItems) do
		if not activeById[itemId] then
			visual:Destroy()
			factory.visualItems[itemId] = nil
		end
	end
end

local function buildResponse(factory: any, success: boolean, reason: string?): { [string]: any }
	return {
		Success = success,
		Reason = reason,
		Layout = layoutForClient(factory.layout),
		Inventory = copyInventory(factory.inventory),
	}
end

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local previous = lastRequestAt[player] or 0
	if now - previous < 0.1 then
		return true
	end
	lastRequestAt[player] = now
	return false
end

local function dataIsReady(player: Player): boolean
	return player:GetAttribute("FactoryDataReady") == true
end

local function commitLayout(factory: any, layout: FactoryLayout.Layout): (boolean, string?)
	local valid, errorMessage = PlacementRules.validateLayout(layout, factory.capacity)
	if not valid then
		return false, errorMessage
	end
	local route = FactoryLayout.toRoute(layout)
	local success, routeError = pcall(function()
		factory.simulation:setRoute(route)
	end)
	if not success then
		return false, tostring(routeError)
	end
	factory.layout = FactoryLayout.copy(layout)
	refreshMachineVisuals(factory)
	return true
end

local function placeMachine(player: Player, machineId: any, slotIndex: any, replaceRequested: any)
	local factory = factories[player]
	if not factory then
		return { Success = false, Reason = "Factory is not ready" }
	end
	if not dataIsReady(player) then
		return buildResponse(factory, false, "Factory data is loading")
	end
	if isRateLimited(player) then
		return buildResponse(factory, false, "Too many requests")
	end
	local valid, errorMessage = PlacementRules.validateMachineForSlot(machineId, slotIndex)
	if not valid then
		return buildResponse(factory, false, errorMessage)
	end
	local previousMachineId = factory.layout[slotIndex]
	if previousMachineId and replaceRequested ~= true then
		return buildResponse(factory, false, "Slot is occupied")
	end
	if (factory.inventory[machineId] or 0) <= 0 then
		return buildResponse(factory, false, "Machine is not in inventory")
	end

	local candidate, candidateError = PlacementRules.createPlacementLayout(factory.layout, machineId, slotIndex, factory.capacity)
	if not candidate then
		return buildResponse(factory, false, candidateError)
	end
	local nextInventory = copyInventory(factory.inventory)
	nextInventory[machineId] = (nextInventory[machineId] or 0) - 1
	if nextInventory[machineId] <= 0 then
		nextInventory[machineId] = nil
	end
	if previousMachineId then
		nextInventory[previousMachineId] = (nextInventory[previousMachineId] or 0) + 1
	end
	for otherSlot = 1, FactoryLayout.SlotCount do
		local oldMachineId = factory.layout[otherSlot]
		if otherSlot ~= slotIndex and oldMachineId and candidate[otherSlot] ~= oldMachineId then
			nextInventory[oldMachineId] = (nextInventory[oldMachineId] or 0) + 1
		end
	end

	local committed, commitError = commitLayout(factory, candidate)
	if not committed then
		return buildResponse(factory, false, commitError)
	end
	factory.inventory = nextInventory
	AnalyticsService.record(player, "MachinePlaced")
	EffectService.fire(player, "InventoryChanged")
	return buildResponse(factory, true)
end

local function removeMachine(player: Player, slotIndex: any)
	local factory = factories[player]
	if not factory then
		return { Success = false, Reason = "Factory is not ready" }
	end
	if not dataIsReady(player) then
		return buildResponse(factory, false, "Factory data is loading")
	end
	if isRateLimited(player) then
		return buildResponse(factory, false, "Too many requests")
	end
	local machineId = factory.layout[slotIndex]
	if not machineId then
		return buildResponse(factory, false, "Slot is already empty")
	end
	local definition = MachineDefinitions.get(machineId)
	if definition and (definition.Category == "Producer" or definition.Category == "Seller") then
		return buildResponse(factory, false, "Keep the dropper at the start and a seller at the route end")
	end
	local candidate, candidateError = PlacementRules.createRemoveLayout(factory.layout, slotIndex, factory.capacity)
	if not candidate then
		return buildResponse(factory, false, candidateError)
	end
	local committed, commitError = commitLayout(factory, candidate)
	if not committed then
		return buildResponse(factory, false, commitError)
	end
	factory.inventory[machineId] = (factory.inventory[machineId] or 0) + 1
	AnalyticsService.record(player, "MachineRemoved")
	EffectService.fire(player, "InventoryChanged")
	return buildResponse(factory, true)
end

local function moveMachine(player: Player, sourceSlotIndex: any, destinationSlotIndex: any)
	local factory = factories[player]
	if not factory then
		return { Success = false, Reason = "Factory is not ready" }
	end
	if not dataIsReady(player) then
		return buildResponse(factory, false, "Factory data is loading")
	end
	if isRateLimited(player) then
		return buildResponse(factory, false, "Too many requests")
	end
	local candidate, candidateError = PlacementRules.createMoveLayout(factory.layout, sourceSlotIndex, destinationSlotIndex, factory.capacity)
	if not candidate then
		return buildResponse(factory, false, candidateError)
	end
	local committed, commitError = commitLayout(factory, candidate)
	if not committed then
		return buildResponse(factory, false, commitError)
	end
	AnalyticsService.record(player, "MachineMoved")
	EffectService.fire(player, "InventoryChanged")
	return buildResponse(factory, true)
end

local function createFactory(player: Player)
	if factories[player] then
		return
	end
	player:SetAttribute("FactoryBuildVersion", FactoryConfig.BuildVersion)
	if player:GetAttribute("FactoryDataReady") == nil then
		player:SetAttribute("FactoryDataReady", false)
	end
	local simulation = FactorySimulation.new({ Route = FactoryLayout.toRoute(FactoryLayout.Default) })
	local plot, origin, conveyor = createPlaceholderPlot(player)
	local factory = {
		simulation = simulation,
		plot = plot,
		conveyor = conveyor,
		origin = origin,
		layout = FactoryLayout.copy(FactoryLayout.Default),
		capacity = 1,
		inventory = {},
		boosterInventory = {},
		visualItems = {},
		announcedSpawn = false,
		announcedSale = false,
	}
	factories[player] = factory
	refreshMachineVisuals(factory)
	updateDebugAttributes(player, factory)
	AnalyticsService.record(player, "FactoryActive")
end

local function removeFactory(player: Player)
	local factory = factories[player]
	if factory then
		factory.plot:Destroy()
		factories[player] = nil
	end
	lastRequestAt[player] = nil
end

local function createRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local factoryRemotes = remotes:FindFirstChild("Factory")
	if not factoryRemotes then
		factoryRemotes = Instance.new("Folder")
		factoryRemotes.Name = "Factory"
		factoryRemotes.Parent = remotes
	end

	local function remoteFunction(name: string): RemoteFunction
		local remote = factoryRemotes:FindFirstChild(name) :: RemoteFunction?
		if not remote then
			remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = factoryRemotes
		end
		return remote
	end

	remoteFunction("PlaceMachine").OnServerInvoke = placeMachine
	remoteFunction("RemoveMachine").OnServerInvoke = removeMachine
	remoteFunction("MoveMachine").OnServerInvoke = moveMachine
	remoteFunction("GetFactoryState").OnServerInvoke = FactoryService.getClientState
end

function FactoryService.getSimulation(player: Player): any?
	local factory = factories[player]
	return factory and factory.simulation
end

function FactoryService.getState(player: Player): any?
	return factories[player]
end

function FactoryService.getClientState(player: Player): { [string]: any }
	local factory = factories[player]
	if not factory then
		return { Success = false, Reason = "Factory is not ready" }
	end
	return {
		Success = true,
		Layout = layoutForClient(factory.layout),
		Inventory = copyInventory(factory.inventory),
		BoosterInventory = copyInventory(factory.boosterInventory),
		Capacity = factory.capacity,
		SlotCount = FactoryLayout.SlotCount,
	}
end

function FactoryService.setCapacity(player: Player, capacity: number): (boolean, string?)
	local factory = factories[player]
	if not factory then
		return false, "Factory is not ready"
	end
	if capacity < factory.capacity or capacity > FactoryConfig.MaxFactoryCapacity then
		return false, "Invalid capacity change"
	end
	factory.capacity = capacity
	updateDebugAttributes(player, factory)
	return true
end

function FactoryService.getPersistentState(player: Player): { [string]: any }?
	local factory = factories[player]
	if not factory then
		return nil
	end
	return {
		Coins = factory.simulation:getSnapshot().Coins,
		Layout = FactoryLayout.copy(factory.layout),
		Inventory = copyInventory(factory.inventory),
		BoosterInventory = copyInventory(factory.boosterInventory),
		Capacity = factory.capacity,
		Statistics = (function()
			local snapshot = factory.simulation:getSnapshot()
			return {
				ProducedItems = snapshot.ProducedItems,
				SoldItems = snapshot.SoldItems,
				TotalValueSold = snapshot.TotalValueSold,
				DroppedItemsAtCap = snapshot.DroppedItemsAtCap,
			}
		end)(),
	}
end

function FactoryService.applyPersistentState(player: Player, data: { [string]: any }): (boolean, string?)
	local factory = factories[player]
	if not factory then
		return false, "Factory is not ready"
	end
	local valid, errorMessage = PlacementRules.validateLayout(data.Layout, data.Capacity)
	if not valid then
		return false, errorMessage
	end
	local route = FactoryLayout.toRoute(data.Layout)
	local routeApplied, routeError = pcall(function()
		factory.simulation:setRoute(route)
	end)
	if not routeApplied then
		return false, tostring(routeError)
	end
	factory.capacity = data.Capacity
	factory.layout = FactoryLayout.copy(data.Layout)
	factory.inventory = copyInventory(data.Inventory)
	factory.boosterInventory = copyInventory(data.BoosterInventory)
	factory.simulation:setCoins(data.Coins)
	refreshMachineVisuals(factory)
	updateDebugAttributes(player, factory)
	return true
end

function FactoryService.start()
	if started then
		return
	end
	started = true
	createRemotes()
	Players.PlayerAdded:Connect(createFactory)
	Players.PlayerRemoving:Connect(function(player)
		-- DataService saves on the same signal. Deferring teardown lets its
		-- handler read the final factory state before the plot is destroyed.
		task.defer(removeFactory, player)
	end)
	for _, player in Players:GetPlayers() do
		createFactory(player)
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		attributeUpdateAccumulator += deltaTime
		for player, factory in pairs(factories) do
			if not dataIsReady(player) then
				continue
			end
			local before = factory.simulation:getSnapshot()
			factory.simulation:step(deltaTime)
			local after = factory.simulation:getSnapshot()
			if not factory.announcedSpawn and after.ProducedItems > before.ProducedItems then
				factory.announcedSpawn = true
				EffectService.fire(player, "FirstItemSpawned")
			end
			if not factory.announcedSale and after.SoldItems > before.SoldItems then
				factory.announcedSale = true
				EffectService.fire(player, "FirstItemSold", { Coins = after.Coins })
			end
			updateVisualItems(factory)
			if attributeUpdateAccumulator >= 0.25 then
				updateDebugAttributes(player, factory)
			end
		end
		if attributeUpdateAccumulator >= 0.25 then
			attributeUpdateAccumulator = 0
		end
	end)
end

return FactoryService
