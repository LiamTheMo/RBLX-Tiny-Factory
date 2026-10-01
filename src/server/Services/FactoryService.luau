--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactoryConfig = require(Shared:WaitForChild("FactoryConfig"))
local FactoryLayout = require(Shared:WaitForChild("FactoryLayout"))
local FactorySimulation = require(Shared:WaitForChild("FactorySimulation"))
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local CubeTypeDefinitions = require(Shared:WaitForChild("CubeTypeDefinitions"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local AnalyticsService = require(script.Parent.AnalyticsService)
local EffectService = require(script.Parent.EffectService)

local FactoryService = {}
local factories = {}
local lastRequestAt = {}
local started = false
local nextPlotIndex = 0
local attributeUpdateAccumulator = 0
local visualUpdateAccumulator = 0
local VISUAL_UPDATE_INTERVAL_SECONDS = 1 / 20
local VISUAL_STATE_COLORS = {
	Painted = Color3.fromRGB(255, 105, 160),
	Golden = Color3.fromRGB(255, 211, 66),
}
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

local function routeSlotsForLayout(layout: FactoryLayout.Layout): { number }
	local routeSlots = {}
	for slotIndex = 1, FactoryLayout.SlotCount do
		if layout[slotIndex] then
			table.insert(routeSlots, slotIndex)
		end
	end
	return routeSlots
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

local function createPlaceholderPlot(player: Player): (Folder, Vector3)
	local plotsFolder = workspace:FindFirstChild("TinyFactoryPlots")
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "TinyFactoryPlots"
		plotsFolder.Parent = workspace
	end

	nextPlotIndex += 1
	local origin = Vector3.new((nextPlotIndex - 1) * 36, 0, 0)
	local plot = Instance.new("Folder")
	plot.Name = `Factory_{player.UserId}`
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot.Parent = plotsFolder

	createPart(plot, "PlotBase", Vector3.new(30, 0.5, 8), origin + Vector3.new(12, -0.25, 0), Color3.fromRGB(73, 55, 42))
	for slotIndex = 0, FactoryLayout.SlotCount - 1 do
		local belt = createPart(plot, `Conveyor_{slotIndex + 1}`, Vector3.new(5.5, 0.15, 2), origin + Vector3.new(slotIndex * 6, 0.1, 0), Color3.fromRGB(66, 75, 84))
		belt.Material = Enum.Material.Metal
		local stripe = createPart(plot, `ConveyorGuide_{slotIndex + 1}`, Vector3.new(4.2, 0.02, 0.16), origin + Vector3.new(slotIndex * 6, 0.2, 0), Color3.fromRGB(90, 210, 230))
		stripe.Material = Enum.Material.Neon
	end
	return plot, origin
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

	local colors = {
		Producer = Color3.fromRGB(82, 145, 255),
		Processor = Color3.fromRGB(255, 194, 66),
		Seller = Color3.fromRGB(83, 207, 113),
	}
	local shapes = {
		Producer = Enum.PartType.Cylinder,
		Processor = Enum.PartType.Block,
		Seller = Enum.PartType.Ball,
	}
	for slotIndex = 1, FactoryLayout.SlotCount do
		local machineId = factory.layout[slotIndex]
		if machineId then
			local definition = MachineDefinitions.get(machineId)
			if definition then
				local machinePart = createPart(
					machineFolder,
					`Slot_{slotIndex}_{machineId}`,
					Vector3.new(2, 2, 2),
					factory.origin + Vector3.new((slotIndex - 1) * 6, 1.1, 0),
					colors[definition.Category] or Color3.fromRGB(235, 235, 235)
				)
				machinePart.Shape = shapes[definition.Category] or Enum.PartType.Block
				machinePart.Material = if definition.Rarity == "Legendary" or definition.Rarity == "Epic" then Enum.Material.Neon else Enum.Material.SmoothPlastic
				machinePart:SetAttribute("MachineId", definition.Id)
				machinePart:SetAttribute("DisplayName", definition.DisplayName)
				machinePart:SetAttribute("Description", definition.Description)
				machinePart:SetAttribute("Rarity", definition.Rarity)
				machinePart:SetAttribute("Behavior", definition.Behavior or "Infrastructure")

				local labelGui = Instance.new("BillboardGui")
				labelGui.Name = "MachineLabel"
				labelGui.Adornee = machinePart
				labelGui.AlwaysOnTop = true
				labelGui.MaxDistance = 80
				labelGui.Size = UDim2.fromOffset(150, 42)
				labelGui.StudsOffset = Vector3.new(0, 1.7, 0)
				labelGui.Parent = machinePart

				local label = Instance.new("TextLabel")
				label.BackgroundColor3 = Color3.fromRGB(28, 24, 21)
				label.BackgroundTransparency = 0.2
				label.BorderSizePixel = 0
				label.Size = UDim2.fromScale(1, 1)
				label.Text = `{definition.DisplayName}\n{definition.Rarity}`
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextSize = 11
				label.TextWrapped = true
				label.Font = Enum.Font.GothamBold
				label.Parent = labelGui
			end
		end
	end
end

local function updateVisualItems(factory: any)
	local activeItems = factory.simulation:getActiveItemsForVisuals()
	local activeById = {}
	for _, item in ipairs(activeItems) do
		activeById[item.Id] = true
		local visual = factory.visualItems[item.Id]
		if not visual then
			visual = createPart(factory.plot, `Item_{item.Id}`, Vector3.new(0.9, 0.9, 0.9), factory.origin + Vector3.new(0, 1, 0), Color3.fromRGB(235, 235, 235))
			factory.visualItems[item.Id] = visual
		end
		local baseColor = cubeTypeColorCache[item.CubeType]
		if not baseColor then
			local cubeType = CubeTypeDefinitions.get(item.CubeType)
			local rgb = cubeType and cubeType.Color
			baseColor = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else Color3.fromRGB(235, 235, 235)
			cubeTypeColorCache[item.CubeType] = baseColor
		end
		local size = 0.9 * math.clamp(item.SizeScale or 1, 0.5, 4)
		local nextSize = Vector3.new(size, size, size)
		if visual.Size ~= nextSize then
			visual.Size = nextSize
		end
		local nextColor = VISUAL_STATE_COLORS[item.VisualState] or baseColor
		if visual.Color ~= nextColor then
			visual.Color = nextColor
		end

		local visualSlotIndex = factory.routeSlots[item.SlotIndex] or 1
		local progress = 1 - math.clamp(item.TimeRemaining / FactoryConfig.TravelTimePerSlotSeconds, 0, 1)
		local x = (visualSlotIndex - 1) * 6 + progress * 6
		local nextPosition = factory.origin + Vector3.new(x, 1.05, 0)
		if visual.Position ~= nextPosition then
			visual.Position = nextPosition
		end
		if visual:GetAttribute("ItemValue") ~= item.Value then
			visual:SetAttribute("ItemValue", item.Value)
		end
		if visual:GetAttribute("CubeType") ~= item.CubeType then
			visual:SetAttribute("CubeType", item.CubeType)
		end
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
	factory.routeSlots = routeSlotsForLayout(factory.layout)
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

	factory.inventory[machineId] -= 1
	factory.layout[slotIndex] = machineId
	if previousMachineId then
		factory.inventory[previousMachineId] = (factory.inventory[previousMachineId] or 0) + 1
	end
	local committed, commitError = commitLayout(factory, factory.layout)
	if not committed then
		factory.inventory[machineId] += 1
		if previousMachineId then
			factory.inventory[previousMachineId] -= 1
		end
		factory.layout[slotIndex] = previousMachineId
		return buildResponse(factory, false, commitError)
	end
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
	local valid, errorMessage = PlacementRules.validateSlotIndex(slotIndex)
	if not valid then
		return buildResponse(factory, false, errorMessage)
	end
	if slotIndex == 1 or slotIndex == FactoryLayout.SlotCount then
		return buildResponse(factory, false, "The producer and seller are required")
	end
	local machineId = factory.layout[slotIndex]
	if not machineId then
		return buildResponse(factory, false, "Slot is already empty")
	end

	factory.layout[slotIndex] = nil
	factory.inventory[machineId] = (factory.inventory[machineId] or 0) + 1
	local committed, commitError = commitLayout(factory, factory.layout)
	if not committed then
		factory.inventory[machineId] -= 1
		factory.layout[slotIndex] = machineId
		return buildResponse(factory, false, commitError)
	end
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
	local sourceValid, sourceError = PlacementRules.validateSlotIndex(sourceSlotIndex)
	local destinationValid, destinationError = PlacementRules.validateSlotIndex(destinationSlotIndex)
	if not sourceValid then
		return buildResponse(factory, false, sourceError)
	end
	if not destinationValid then
		return buildResponse(factory, false, destinationError)
	end
	local machineId = factory.layout[sourceSlotIndex]
	if not machineId then
		return buildResponse(factory, false, "Source slot is empty")
	end
	if factory.layout[destinationSlotIndex] then
		return buildResponse(factory, false, "Destination slot is occupied")
	end
	local machineValid, machineError = PlacementRules.validateMachineForSlot(machineId, destinationSlotIndex)
	if not machineValid then
		return buildResponse(factory, false, machineError)
	end

	factory.layout[sourceSlotIndex] = nil
	factory.layout[destinationSlotIndex] = machineId
	local committed, commitError = commitLayout(factory, factory.layout)
	if not committed then
		factory.layout[destinationSlotIndex] = nil
		factory.layout[sourceSlotIndex] = machineId
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
	local plot, origin = createPlaceholderPlot(player)
	local factory = {
		simulation = simulation,
		plot = plot,
		origin = origin,
		layout = FactoryLayout.copy(FactoryLayout.Default),
		routeSlots = routeSlotsForLayout(FactoryLayout.Default),
		capacity = 1,
		inventory = {},
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
	local snapshot = factory.simulation:getSnapshot()
	return {
		Coins = snapshot.Coins,
		Layout = FactoryLayout.copy(factory.layout),
		Inventory = copyInventory(factory.inventory),
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
	factory.routeSlots = routeSlotsForLayout(factory.layout)
	factory.inventory = copyInventory(data.Inventory)
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
		if shouldUpdateVisuals then
			visualUpdateAccumulator %= VISUAL_UPDATE_INTERVAL_SECONDS
		end
		for player, factory in pairs(factories) do
			if not dataIsReady(player) then
				continue
			end
			local produced, sold = factory.simulation:step(deltaTime)
			if not factory.announcedSpawn and produced then
				factory.announcedSpawn = true
				EffectService.fire(player, "FirstItemSpawned")
			end
			if not factory.announcedSale and sold then
				factory.announcedSale = true
				EffectService.fire(player, "FirstItemSold", { Coins = factory.simulation:getCoins() })
			end
			if shouldUpdateVisuals then
				updateVisualItems(factory)
			end
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
