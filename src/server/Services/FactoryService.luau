--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactoryConfig = require(Shared:WaitForChild("FactoryConfig"))
local CubeTypeDefinitions = require(Shared:WaitForChild("CubeTypeDefinitions"))
local MachineVisualConfig = require(Shared:WaitForChild("MachineVisualConfig"))
local FactoryLayout = require(Shared:WaitForChild("FactoryLayout"))
local FactoryItemGeometry = require(Shared:WaitForChild("FactoryItemGeometry"))
local SaleValueRules = require(Shared:WaitForChild("SaleValueRules"))
local NumberFormatter = require(Shared:WaitForChild("NumberFormatter"))
local MachineModelBuilder = require(script.Parent.MachineModelBuilder)
local FactorySimulation = require(Shared:WaitForChild("FactorySimulation"))
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local AnalyticsService = require(script.Parent.AnalyticsService)
local EffectService = require(script.Parent.EffectService)
local IslandWorldConfig = require(Shared:WaitForChild("IslandWorldConfig"))

local FactoryService = {}
local factories = {}
local lastRequestAt = {}
local started = false
local occupiedPlots = {}
local attributeUpdateAccumulator = 0
local visualUpdateAccumulator = 0
local VISUAL_UPDATE_INTERVAL_SECONDS = 1 / 20
local cubeTypeColorCache = {}

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

local function overlapsHitbox(hitbox: BasePart, item: BasePart): boolean
	local localPosition = hitbox.CFrame:PointToObjectSpace(item.Position)
	return FactoryItemGeometry.overlapsBox(localPosition.X, localPosition.Y, localPosition.Z, hitbox.Size.X, hitbox.Size.Y, hitbox.Size.Z, item.Size.X)
end

local function getSaleBuffModifiers(player: Player): { [string]: number? }
	-- EconomyService owns these server-side attributes. Missing attributes remain neutral.
	local expiresAt = player:GetAttribute("FactorySaleValueExpiresAt")
	if type(expiresAt) ~= "number" or expiresAt <= workspace:GetServerTimeNow() then
		return { AdditiveBonus = 0, Multiplier = 1 }
	end
	return {
		AdditiveBonus = player:GetAttribute("FactorySaleValueAdditiveBonus"),
		Multiplier = player:GetAttribute("FactorySaleValueMultiplier"),
	}
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

local function createIslandPlot(player: Player, plotIndex: number): (Folder, Vector3, Folder)
	local plotsFolder = workspace:FindFirstChild("TinyFactoryPlots")
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "TinyFactoryPlots"
		plotsFolder.Parent = workspace
	end

	local plotConfig = MachineVisualConfig.FactoryPlot
	local position = IslandWorldConfig.getPlotOrigin(plotIndex)
	local origin = Vector3.new(position.X, position.Y, position.Z)
	local plot = Instance.new("Folder")
	plot.Name = string.format("Factory_%d", player.UserId)
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("IslandIndex", plotIndex)
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
	factory.sellerHitbox = nil

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
				local model, clickPart, sellerHitbox = MachineModelBuilder.build(machineFolder, factory.origin, slotIndex, definition)
				if sellerHitbox then factory.sellerHitbox = sellerHitbox end
				for _, part in ipairs(model:GetChildren()) do
					if part:IsA("BasePart") and part ~= sellerHitbox then addSlotClickDetector(part, slotIndex) end
				end
				clickPart:SetAttribute("MachineId", definition.Id)
				clickPart:SetAttribute("DisplayName", definition.DisplayName)
				clickPart:SetAttribute("Description", definition.Description)
				clickPart:SetAttribute("Rarity", definition.Rarity)
				clickPart:SetAttribute("Behavior", definition.Behavior or definition.Category)

			end
		end
	end
end

local function updateVisualItems(player: Player, factory: any): boolean
	local activeItems = factory.simulation:getActiveItemsForDebug()
	local activeById = {}
	local visualConfig = MachineVisualConfig.ConveyorItem
	local buffModifiers = getSaleBuffModifiers(player)
	local seller = MachineDefinitions.get(factory.layout[FactoryLayout.SellerSlotIndex])
	local soldAny = false
	factory.itemPresentationState = factory.itemPresentationState or {}
	local function setAttribute(part: BasePart, name: string, value: any)
		if part:GetAttribute(name) ~= value then part:SetAttribute(name, value) end
	end
	for _, item in ipairs(activeItems) do
		activeById[item.Id] = true
		local visual = factory.visualItems[item.Id]
		if not visual then
			visual = createPart(factory.plot, string.format("Item_%d", item.Id), Vector3.new(visualConfig.Size, visualConfig.Size, visualConfig.Size), factory.origin + Vector3.new(0, visualConfig.DropStartHeight + MachineVisualConfig.Conveyor.Elevation, 0), Color3.fromRGB(235, 235, 235))
			visual:SetAttribute("FactoryItem", true)
			visual:SetAttribute("OwnerUserId", player.UserId)
			visual:SetAttribute("ItemId", item.Id)
			factory.visualItems[item.Id] = visual
		end
		local cubeColor = cubeTypeColorCache[item.TypeId]
		if not cubeColor then
			local cubeType = CubeTypeDefinitions.get(item.TypeId)
			local color = cubeType and cubeType.Color
			cubeColor = if color then Color3.fromRGB(color[1], color[2], color[3]) else Color3.fromRGB(235, 235, 235)
			cubeTypeColorCache[item.TypeId] = cubeColor
		end
		local stateColors = {
			Base = cubeColor,
			Painted = Color3.fromRGB(255, 105, 160),
			Golden = Color3.fromRGB(255, 211, 66),
		}
		local size = visualConfig.Size * math.clamp(item.SizeScale or 1, 0.5, 4)
		local nextSize = Vector3.new(size, size, size)
		if visual.Size ~= nextSize then visual.Size = nextSize end
		local nextColor = stateColors[item.VisualState] or stateColors.Base
		if visual.Color ~= nextColor then visual.Color = nextColor end

		local x, y = FactoryItemGeometry.itemPosition(factory.layout, item)
		local nextPosition = factory.origin + Vector3.new(x, y, 0)
		if visual.Position ~= nextPosition then visual.Position = nextPosition end
		local cache = factory.itemPresentationState[item.Id]
		local sellerModifiers = factory.simulation:getSaleModifiers(item.Id) or (seller and seller.SaleModifiers)
		local typeAdd, typeMult = item.TypeModifiers.AdditiveBonus or 0, item.TypeModifiers.Multiplier or 1
		local buffAdd, buffMult = buffModifiers.AdditiveBonus or 0, buffModifiers.Multiplier or 1
		local sellerAdd, sellerMult = if sellerModifiers then sellerModifiers.AdditiveBonus or 0 else 0, if sellerModifiers then sellerModifiers.Multiplier or 1 else 1
		if not cache or cache.Value ~= item.Value or cache.Count ~= #item.ModifierLabels
			or cache.TypeAdd ~= typeAdd or cache.TypeMult ~= typeMult
			or cache.BuffAdd ~= buffAdd or cache.BuffMult ~= buffMult
			or cache.SellerAdd ~= sellerAdd or cache.SellerMult ~= sellerMult then
			local breakdown = SaleValueRules.getBreakdown(item.Value, item.TypeModifiers, buffModifiers, sellerModifiers, FactoryConfig.MaxItemValue)
			setAttribute(visual, "ItemValue", item.Value)
			setAttribute(visual, "ItemBaseValue", item.BaseValue)
			setAttribute(visual, "ItemType", item.TypeId)
			setAttribute(visual, "ItemModifiers", table.concat(item.ModifierLabels, " · "))
			setAttribute(visual, "ItemChainMultiplier", item.Value / item.BaseValue)
			if breakdown then
				setAttribute(visual, "ItemSaleValue", breakdown.Value)
				setAttribute(visual, "ItemSaleMultiplier", breakdown.Multiplier)
				setAttribute(visual, "ItemAdditiveBonus", breakdown.AdditiveBonus)
			end
			local layers = {}
			local function describeLayer(name: string, layer: any)
				if layer and ((layer.AdditiveBonus or 0) ~= 0 or (layer.Multiplier or 1) ~= 1) then
					table.insert(layers, name .. " +" .. NumberFormatter.format(layer.AdditiveBonus or 0) .. " ×" .. NumberFormatter.format(layer.Multiplier or 1))
				end
			end
			describeLayer("Type", item.TypeModifiers)
			describeLayer("Buff", buffModifiers)
			describeLayer("Seller", sellerModifiers)
			setAttribute(visual, "ItemSaleLayers", if #layers > 0 then table.concat(layers, " · ") else "No sale bonuses")
			factory.itemPresentationState[item.Id] = { Value = item.Value, Count = #item.ModifierLabels,
				TypeAdd = typeAdd, TypeMult = typeMult, BuffAdd = buffAdd, BuffMult = buffMult, SellerAdd = sellerAdd, SellerMult = sellerMult }
		end

		local sellerHitbox = factory.sellerHitbox
		if item.ReadyForSale and sellerHitbox and overlapsHitbox(sellerHitbox, visual) then
			local sold, credited = factory.simulation:sellItem(item.Id, buffModifiers)
			if sold then
				soldAny = true
				EffectService.fire(player, "ItemSold", { Coins = credited, Balance = factory.simulation:getCoins(), Position = visual.Position, ItemId = item.Id })
				activeById[item.Id] = nil
			end
		end
	end

	if soldAny then updateDebugAttributes(player, factory) end

	for itemId, visual in pairs(factory.visualItems) do
		if not activeById[itemId] then
			visual:Destroy()
			factory.visualItems[itemId] = nil
			factory.itemPresentationState[itemId] = nil
		end
	end
	return soldAny
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
	local plotIndex = IslandWorldConfig.findFreePlot(occupiedPlots)
	if not plotIndex then
		player:Kick("All six factory islands are occupied. Please join another server.")
		return
	end
	occupiedPlots[plotIndex] = true
	player:SetAttribute("FactoryBuildVersion", FactoryConfig.BuildVersion)
	if player:GetAttribute("FactoryDataReady") == nil then
		player:SetAttribute("FactoryDataReady", false)
	end
	local simulation = FactorySimulation.new({ Route = FactoryLayout.toRoute(FactoryLayout.Default) })
	local plot, origin, conveyor = createIslandPlot(player, plotIndex)
	local factory = {
		simulation = simulation,
		plot = plot,
		conveyor = conveyor,
		origin = origin,
		plotIndex = plotIndex,
		layout = FactoryLayout.copy(FactoryLayout.Default),
		capacity = 1,
		inventory = {},
		boosterInventory = {},
		visualItems = {},
		announcedSpawn = false,
		announcedSale = false,
	}
	factories[player] = factory
	local world = workspace:FindFirstChild(IslandWorldConfig.MapKey)
	local island = if world then world:FindFirstChild(string.format("StarterIsland_%02d", plotIndex)) else nil
	local islandSpawn = if island then island:FindFirstChild("IslandSpawn") else nil
	if islandSpawn and islandSpawn:IsA("SpawnLocation") then
		islandSpawn.Enabled = true
		player.RespawnLocation = islandSpawn
		island:SetAttribute("OwnerUserId", player.UserId)
	end
	local function placeCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and factories[player] == factory and character.Parent then
			character:PivotTo(CFrame.new(origin + Vector3.new(15, 4, 15)))
		end
	end
	factory.characterConnection = player.CharacterAdded:Connect(placeCharacter)
	if player.Character then task.spawn(placeCharacter, player.Character) end
	refreshMachineVisuals(factory)
	updateDebugAttributes(player, factory)
end

local function removeFactory(player: Player)
	local factory = factories[player]
	if factory then
		occupiedPlots[factory.plotIndex] = nil
		if factory.characterConnection then factory.characterConnection:Disconnect() end
		player.RespawnLocation = nil
		local world = workspace:FindFirstChild(IslandWorldConfig.MapKey)
		local island = if world then world:FindFirstChild(string.format("StarterIsland_%02d", factory.plotIndex)) else nil
		if island then
			island:SetAttribute("OwnerUserId", nil)
			local spawn = island:FindFirstChild("IslandSpawn")
			if spawn and spawn:IsA("SpawnLocation") then spawn.Enabled = false end
		end
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
		Coins = factory.simulation:getCoins(),
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
		visualUpdateAccumulator += deltaTime
		local shouldUpdateVisuals = visualUpdateAccumulator >= VISUAL_UPDATE_INTERVAL_SECONDS
		if shouldUpdateVisuals then visualUpdateAccumulator %= VISUAL_UPDATE_INTERVAL_SECONDS end
		for player, factory in pairs(factories) do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") and root.Position.Y < IslandWorldConfig.WaterY - 10 then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				character:PivotTo(CFrame.new(factory.origin + Vector3.new(15, 4, 15)))
			end
			if not dataIsReady(player) then continue end
			local produced = factory.simulation:step(deltaTime)
			local sold = if shouldUpdateVisuals then updateVisualItems(player, factory) else false
			if not factory.announcedSpawn and produced then
				factory.announcedSpawn = true
				AnalyticsService.record(player, "FirstItemProduced")
				EffectService.fire(player, "FirstItemSpawned")
			end
			if not factory.announcedSale and sold then
				factory.announcedSale = true
				AnalyticsService.record(player, "FirstItemSold")
				EffectService.fire(player, "FirstItemSold", { Coins = factory.simulation:getCoins() })
			end
			if attributeUpdateAccumulator >= 0.25 then updateDebugAttributes(player, factory) end
		end
		if attributeUpdateAccumulator >= 0.25 then attributeUpdateAccumulator = 0 end
	end)
end

return FactoryService
