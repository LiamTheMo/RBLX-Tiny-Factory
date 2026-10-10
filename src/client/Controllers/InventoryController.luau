--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local FactoryLayout = require(Shared:WaitForChild("FactoryLayout"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))
local BoosterConfig = require(Shared:WaitForChild("BoosterConfig"))

local MACHINE_SECTIONS = {
	{ Category = "Producer", Title = "Droppers" },
	{ Category = "Processor", Title = "Upgraders" },
	{ Category = "Seller", Title = "Sellers" },
}

local UI = require(script.Parent.AmberUI)
local Layout = require(Shared.AmberLayout)
local ModelBuilder = require(Shared.MachineModelBuilder)
local InventoryController = {}
local started = false
local openPanel: ((string, number?, string?) -> ())? = nil
local closePanel: (() -> ())? = nil

local COLORS = {
	Panel = UI.Panel,
	Row = UI.Panel,
	Button = Color3.fromRGB(68, 61, 77),
	Accent = Color3.fromRGB(255, 210, 128),
	Text = UI.Text,
	Muted = UI.Muted,
	Good = Color3.fromRGB(155, 230, 166),
	Bad = Color3.fromRGB(255, 155, 145),
}

local rarityColors: { [string]: Color3 } = {}
for _, band in ipairs(EconomyConfig.RarityOddsBands) do
	local color = band.Color
	rarityColors[band.Name] = Color3.fromRGB(color[1], color[2], color[3])
end

local function makeLabel(parent: Instance, name: string, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = COLORS.Text
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.BackgroundColor3 = COLORS.Button
	button.BorderSizePixel = 0
	button.TextColor3 = COLORS.Text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Parent = parent
	UI.skin(button, "Tab")
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = button
	return button
end

local function addCorner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function clearRows(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function InventoryController.openInventory(category: string?)
	if openPanel then
		openPanel("Inventory", nil, category)
	end
end

function InventoryController.openPlacement(slotIndex: number)
	if openPanel then
		openPanel("Placement", slotIndex)
	end
end

function InventoryController.close()
	if closePanel then
		closePanel()
	end
end

function InventoryController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Factory")
	local getFactoryState = remotes:WaitForChild("GetFactoryState") :: RemoteFunction
	local placeMachine = remotes:WaitForChild("PlaceMachine") :: RemoteFunction
	local removeMachine = remotes:WaitForChild("RemoveMachine") :: RemoteFunction
	local moveMachine = remotes:WaitForChild("MoveMachine") :: RemoteFunction
	local sellMachine = remotes:WaitForChild("SellMachine") :: RemoteFunction
	local useBooster = remotes:WaitForChild("UseBooster") :: RemoteFunction
	local presentationEvent = remotes:WaitForChild("PresentationEvent") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FactoryInventoryHud"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 15
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = playerGui

	local inventoryButton = makeButton(screenGui, "InventoryButton", "Inventory")
	inventoryButton.Size = UDim2.fromOffset(136, 40)
	inventoryButton.BackgroundColor3 = COLORS.Panel
	inventoryButton.TextSize = 14
	inventoryButton.Text = ""
	UI.asset(inventoryButton.AmberBackground, "Inventory")

	local panel = Instance.new("Frame")
	panel.Name = "MachinePanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	UI.skin(panel, "Panel")
	addCorner(panel, 16)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(120, 108, 137)
	panelStroke.Transparency = 1
	panelStroke.Thickness = 1
	panelStroke.Parent = panel

	local title = makeLabel(panel, "PanelTitle", "Inventory")
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -76, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLORS.Accent
	title.TextSize = 28
	local chest = UI.image(panel, "Chest")
	chest.Position = UDim2.fromOffset(24, 12)
	chest.Size = UDim2.fromOffset(44, 44)

	local closeButton = makeButton(panel, "CloseButton", "×")
	closeButton.Position = UDim2.new(1, -50, 0, 9)
	closeButton.Size = UDim2.fromOffset(38, 34)
	closeButton.TextSize = 20
	closeButton.Text = ""
	UI.asset(closeButton.AmberBackground, "Close")

	local subtitle = makeLabel(panel, "Subtitle", "")
	subtitle.Position = UDim2.fromOffset(18, 42)
	subtitle.Size = UDim2.new(1, -36, 0, 22)
	subtitle.TextColor3 = COLORS.Muted
	subtitle.TextSize = 12

	local status = makeLabel(panel, "Status", "Loading factory inventory...")
	status.Position = UDim2.fromOffset(18, 66)
	status.Size = UDim2.new(1, -36, 0, 24)
	status.TextSize = 12

	local machinesTab = makeButton(panel, "MachinesTab", "Machines")
	machinesTab.Position = UDim2.fromOffset(18, 96)
	machinesTab.Size = UDim2.fromOffset(116, 32)
	local boostersTab = makeButton(panel, "BoostersTab", "Boosters")
	boostersTab.Position = UDim2.fromOffset(142, 96)
	boostersTab.Size = UDim2.fromOffset(116, 32)

	local list = Instance.new("ScrollingFrame")
	list.Name = "MachineList"
	list.Position = UDim2.fromOffset(12, 136)
	list.Size = UDim2.new(1, -24, 1, -148)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = if UserInputService.TouchEnabled then 3 else 5
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = panel
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingBottom = UDim.new(0, 6)
	listPadding.PaddingLeft = UDim.new(0, 2)
	listPadding.PaddingRight = UDim.new(0, 2)
	listPadding.PaddingTop = UDim.new(0, 2)
	listPadding.Parent = list
	local listLayout = Instance.new("UIGridLayout")
	listLayout.CellPadding = UDim2.fromOffset(8, 10)
	listLayout.CellSize = UDim2.new(1/3, -9, 0, 280)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local state: any = nil
	local landscapeCompact = false
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local mode = "Inventory"
	local activeTab = "Machines"
	local activeCategory = "Producer"
	local categoryTabs: { [string]: TextButton } = { Producer = machinesTab, Booster = boostersTab }
	for _, section in ipairs(MACHINE_SECTIONS) do
		if section.Category ~= "Producer" then
			categoryTabs[section.Category] = makeButton(panel, section.Category .. "Tab", section.Title)
		end
	end
	machinesTab.Text = "Droppers"
	for key, button in pairs(categoryTabs) do
		local icon = UI.image(button, key)
		icon.Position = UDim2.fromScale(0.06, 0.23)
		icon.Size = UDim2.fromScale(0.22, 0.5)
		UI.caption(button, 0.28)
	end
	local targetSlot: number? = nil

	local function setStatus(message: string, success: boolean?)
		status.Text = message
		status.TextColor3 = if success == true then COLORS.Good elseif success == false then COLORS.Bad else COLORS.Muted
	end

	local function invoke(remote: RemoteFunction, ...: any): any
		local arguments = { ... }
		local success, result = pcall(function()
			return remote:InvokeServer(table.unpack(arguments))
		end)
		if not success then
			setStatus("Request failed. Try again.", false)
			return nil
		end
		return result
	end

	local function normalizeLayout(): { [number]: string }
		local result: { [number]: string } = {}
		if not state then
			return result
		end
		for slotIndex = 1, state.SlotCount or FactoryLayout.SlotCount do
			local machineId = state.Layout and state.Layout[slotIndex]
			if type(machineId) == "string" and machineId ~= "" then
				result[slotIndex] = machineId
			end
		end
		return result
	end

	local function getCounts(): ({ string }, { [string]: number }, { [string]: number }, { [string]: number })
		local totals: { [string]: number } = {}
		local placed: { [string]: number } = {}
		local available: { [string]: number } = {}
		for machineId in pairs(MachineDefinitions.all()) do
			totals[machineId] = 0
			placed[machineId] = 0
		end
		for machineId, quantity in pairs(state and state.Inventory or {}) do
			local count = math.max(0, math.floor(tonumber(quantity) or 0))
			available[machineId] = count
			totals[machineId] = (totals[machineId] or 0) + count
			placed[machineId] = placed[machineId] or 0
		end
		local layout = normalizeLayout()
		for slotIndex = 1, state.SlotCount or FactoryLayout.SlotCount do
			local machineId = layout[slotIndex]
			if machineId then
				placed[machineId] = (placed[machineId] or 0) + 1
				totals[machineId] = (totals[machineId] or 0) + 1
			end
		end
		local ids = {}
		for machineId, count in pairs(totals) do
			if count > 0 then
				table.insert(ids, machineId)
			end
		end
		table.sort(ids, function(left, right)
			local leftDefinition = MachineDefinitions.get(left)
			local rightDefinition = MachineDefinitions.get(right)
			local leftName = leftDefinition and leftDefinition.DisplayName or left
			local rightName = rightDefinition and rightDefinition.DisplayName or right
			return leftName < rightName
		end)
		return ids, totals, placed, available
	end


	local render: () -> ()
	local function refresh()
		local response = invoke(getFactoryState)
		if response and response.Success then
			state = response
			render()
		elseif response then
			setStatus(response.Reason or "Factory is not ready.", false)
		end
	end

	local function makeRow(machineId: string, rowIndex: number, isPlacement: boolean, availableCount: number, placedCount: number, totalCount: number, actionText: string?, actionEnabled: boolean, action: (() -> ())?, detailOverride: string?): Frame
		local definition = MachineDefinitions.get(machineId)
		local row = Instance.new("Frame")
		row.Name = if isPlacement then string.format("Place_%s_%d", machineId, rowIndex) else "Owned_" .. machineId
		row.LayoutOrder = rowIndex
		row.Parent = list
		UI.skin(row, if isPlacement and actionEnabled then "SelectedCard" else "Card")
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "MachinePreview"
		viewport.BackgroundTransparency = 1
		viewport.Position = UDim2.fromScale(0.09, 0.06)
		viewport.Size = UDim2.fromScale(0.82, 0.43)
		viewport.Ambient = Color3.fromRGB(220, 209, 189)
		viewport.LightColor = Color3.fromRGB(255, 239, 210)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.Parent = row
		if definition then
			local world = Instance.new("WorldModel")
			world.Parent = viewport
			local model = ModelBuilder.build(world, Vector3.zero, 1, definition)
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("BasePart") and child.Transparency == 1 then child:Destroy() end
			end
			local box, size = model:GetBoundingBox()
			local camera = Instance.new("Camera")
			camera.FieldOfView = 35
			local distance = math.max(size.X, size.Y, size.Z) * 2.3
			camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(-distance, distance * 0.65, -distance), box.Position)
			camera.Parent = viewport
			viewport.CurrentCamera = camera
		end
		local nameLabel = makeLabel(row, "MachineName", definition and definition.DisplayName or machineId)
		nameLabel.Position = UDim2.fromScale(0.07, 0.48)
		nameLabel.Size = UDim2.fromScale(0.86, 0.09)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		local rarity = definition and definition.Rarity or "Common"
		if UI.Assets[rarity] then
			local badge = UI.image(row, rarity)
			badge.Position = UDim2.fromScale(0.18, 0.55)
			badge.Size = UDim2.fromScale(0.64, 0.14)
			badge.ScaleType = Enum.ScaleType.Stretch
		else
			local badge = makeLabel(row, "Rarity", rarity)
			badge.Position = UDim2.fromScale(0.1, 0.56)
			badge.Size = UDim2.fromScale(0.8, 0.12)
			badge.TextColor3 = rarityColors[rarity] or COLORS.Text
		end
		local odds = if definition and definition.Rollable then EconomyRules.getMachineOddsLabel(machineId, MachineDefinitions.getRollPool()) else "Starter"
		local oddsLabel = makeLabel(row, "RollOdds", odds or "")
		oddsLabel.Position = UDim2.fromScale(0.1, 0.68)
		oddsLabel.Size = UDim2.fromScale(0.8, 0.07)
		oddsLabel.TextXAlignment = Enum.TextXAlignment.Center
		local details = makeLabel(row, "MachineDetails", string.format("Owned %d  ·  Placed %d  ·  Free %d", totalCount, placedCount, availableCount))
		details.Position = UDim2.fromScale(0.07, 0.76)
		details.Size = UDim2.fromScale(0.86, 0.065)
		details.TextSize = 10
		details.TextXAlignment = Enum.TextXAlignment.Center
		details.TextColor3 = COLORS.Muted
		if isPlacement then details.Text = detailOverride or details.Text end
		row:SetAttribute("Description", definition and definition.Description or "")
		if actionText then
			local button = makeButton(row, "ActionButton", actionText)
			UI.asset(button.AmberBackground, "Action")
			button.Position = UDim2.fromScale(0.08, 0.83)
			button.Size = UDim2.new(0.84, 0, 0, 44)
			button.Position = UDim2.new(0.08, 0, 1, -54)
			button.TextColor3 = COLORS.Panel
			button.Active = actionEnabled
			local confirmed = false
			button.Activated:Connect(function()
				if actionText == "Recycle" and not confirmed then
					confirmed = true
					button.Text = "Confirm recycle"
					return
				end
				if actionEnabled and action then action() end
			end)
		end
		if landscapeCompact then
			viewport.Position = UDim2.fromScale(0.04, 0.06)
			viewport.Size = UDim2.fromScale(0.36, 0.78)
			nameLabel.Position = UDim2.fromScale(0.43, 0.09)
			nameLabel.Size = UDim2.fromScale(0.53, 0.16)
			local badge = row:FindFirstChild(rarity .. "Artwork") or row:FindFirstChild("Rarity")
			if badge and badge:IsA("GuiObject") then
				badge.Position = UDim2.fromScale(0.48, 0.26)
				badge.Size = UDim2.fromScale(0.43, 0.17)
			end
			oddsLabel.Position = UDim2.fromScale(0.43, 0.45)
			oddsLabel.Size = UDim2.fromScale(0.53, 0.12)
			details.Position = UDim2.fromScale(0.43, 0.58)
			details.Size = UDim2.fromScale(0.53, 0.09)
			local button = row:FindFirstChild("ActionButton")
			if button and button:IsA("TextButton") then
				button.Position = UDim2.new(0.43, 0, 1, -54)
				button.Size = UDim2.new(0.53, 0, 0, 44)
			end
		end
		return row
	end

	render = function()
		clearRows(list)
		if not state then
			title.Text = "Inventory"
			subtitle.Text = "Factory data is not ready yet."
			setStatus("Waiting for the factory to load...", nil)
			return
		end

		for category, button in pairs(categoryTabs) do
			button.Visible = mode == "Inventory"
			local selected = if category == "Booster" then activeTab == "Boosters" else activeTab == "Machines" and activeCategory == category
			UI.asset(button.AmberBackground, if selected then "SelectedTab" else "Tab")
		end

		local ids, totals, placed, available = getCounts()
		local ownedCount = 0
		for _, count in pairs(totals) do
			ownedCount += count
		end
		inventoryButton:SetAttribute("OwnedCount", ownedCount)
		local visibleRowCount = 0

		if mode == "Placement" and targetSlot then
			local placementSlot = targetSlot :: number
			local requiredCategory = FactoryLayout.expectedCategoryForSlot(placementSlot)
			local areaLabel = FactoryLayout.getAreaLabel(placementSlot)
			title.Text = if requiredCategory == "Seller" then "Select Seller" else string.format("Place in Area %d", placementSlot)
			subtitle.Text = if requiredCategory == "Seller" then "Choose a seller you own for the end of the conveyor."
				elseif requiredCategory == "Producer" then "Choose a dropper you own." else "Choose an upgrader you own."
			local currentId = state.Layout[placementSlot]
			local currentDefinition = if currentId and currentId ~= "" then MachineDefinitions.get(currentId) else nil
			local currentName = if currentId and currentId ~= "" then (currentDefinition and currentDefinition.DisplayName or currentId) else "Empty"
			local currentMachineName = currentDefinition and currentDefinition.DisplayName or currentName
			setStatus(string.format("%s · %s · Capacity %d", areaLabel, currentName, state.Capacity), nil)

			local layout = normalizeLayout()
			local rowIndex = 0
			for _, machineId in ipairs(ids) do
				local count = available[machineId] or 0
				local machineDefinition = MachineDefinitions.get(machineId)
				if count > 0 and machineDefinition and machineDefinition.Category == requiredCategory then
					rowIndex += 1
					local candidate, placementError = PlacementRules.createPlacementLayout(layout, machineId, placementSlot, state.Capacity)
					local canPlace = candidate ~= nil
					local definition = MachineDefinitions.get(machineId)
					local detail = if canPlace
						then string.format("%s · Available ×%d", definition and definition.Rarity or "Unknown", count)
						else string.format("%s · %s", definition and definition.Rarity or "Unknown", placementError or "Cannot place here")
					makeRow(machineId, rowIndex, true, count, placed[machineId] or 0, totals[machineId] or 0, if currentId and currentId ~= "" then "Replace" else "Place", canPlace, function()
						local response = invoke(placeMachine, machineId, placementSlot, currentId ~= nil and currentId ~= "")
						if response and response.Success then
							local placedDefinition = MachineDefinitions.get(machineId)
							setStatus(string.format("Placed %s in area %d.", placedDefinition and placedDefinition.DisplayName or machineId, placementSlot), true)
							refresh()
						elseif response then
							setStatus(response.Reason or "Machine could not be placed.", false)
							refresh()
						end
					end, detail)
					visibleRowCount += 1
				end
			end

			for sourceSlot = 1, state.SlotCount do
				local sourceId = layout[sourceSlot]
				local sourceDefinition = sourceId and MachineDefinitions.get(sourceId)
				if sourceId and sourceDefinition and sourceDefinition.Category == requiredCategory and sourceSlot ~= placementSlot then
					local candidate, moveError = PlacementRules.createMoveLayout(layout, sourceSlot, placementSlot, state.Capacity)
					rowIndex += 1
					local sourceName = sourceDefinition and sourceDefinition.DisplayName or sourceId
					local canMove = candidate ~= nil
					local detail = if canMove
						then string.format("%s · currently in area %d", sourceDefinition and sourceDefinition.Rarity or "Unknown", sourceSlot)
						else string.format("%s · %s", sourceDefinition and sourceDefinition.Rarity or "Unknown", moveError or "Cannot move here")
					makeRow(sourceId, rowIndex, true, 0, placed[sourceId] or 0, totals[sourceId] or 0, string.format("Move %d", sourceSlot), canMove, function()
						local response = invoke(moveMachine, sourceSlot, placementSlot)
						if response and response.Success then
							setStatus(string.format("Moved %s to area %d.", sourceName, placementSlot), true)
							refresh()
						elseif response then
							setStatus(response.Reason or "Machine could not be moved.", false)
							refresh()
						end
					end, detail)
					visibleRowCount += 1
				end
			end

			local removable = PlacementRules.createRemoveLayout(layout, placementSlot, state.Capacity)
			if removable and currentId and currentId ~= "" and currentDefinition and currentDefinition.Category == "Processor" then
				rowIndex += 1
				makeRow(currentId, rowIndex, true, available[currentId] or 0, placed[currentId] or 0, totals[currentId] or 0, "Return", true, function()
					local response = invoke(removeMachine, placementSlot)
					if response and response.Success then
						setStatus(string.format("Returned %s to your available machines.", currentMachineName), true)
						refresh()
					elseif response then
						setStatus(response.Reason or "Machine could not be returned.", false)
					end
				end, string.format("%s · installed in this area", currentDefinition.Rarity))
				visibleRowCount += 1
			end
		else
			title.Text = "Inventory"
			if activeTab == "Boosters" then
				subtitle.Text = "Collected modifiers stay here until you use them."
				setStatus("Run over world drops to collect boosters.", nil)
				local boosterCounts = state.BoosterInventory or {}
				local rowIndex = 0
				for _, booster in ipairs(BoosterConfig.Definitions) do
					local count = boosterCounts[booster.Id] or 0
					if count > 0 then
						rowIndex += 1
						local row = Instance.new("Frame")
						row.Name = "Booster_" .. booster.Id
						row.LayoutOrder = rowIndex
						row.Size = UDim2.new(1, -8, 0, 280)
						row.BackgroundColor3 = COLORS.Row
						row.BorderSizePixel = 0
						row.Parent = list
						UI.skin(row, "Card")
						local potion = UI.image(row, "Booster")
						potion.Position = UDim2.fromScale(0.2, 0.06)
						potion.Size = UDim2.fromScale(0.6, 0.43)
						local nameLabel = makeLabel(row, "BoosterName", booster.DisplayName)
						nameLabel.Position = UDim2.fromScale(0.08, 0.50)
						nameLabel.Size = UDim2.fromScale(0.84, 0.14)
						nameLabel.Font = Enum.Font.GothamBold
						nameLabel.TextColor3 = Color3.fromRGB(booster.Color[1], booster.Color[2], booster.Color[3])
						local detail = makeLabel(row, "BoosterDetails", string.format("Owned ×%d · %s", count, booster.Effect.Kind))
						detail.Position = UDim2.fromScale(0.08, 0.66)
						detail.Size = UDim2.fromScale(0.84, 0.12)
						detail.TextColor3 = COLORS.Muted
						local button = makeButton(row, "UseButton", "Use")
						button.AnchorPoint = Vector2.new(1, 0.5)
						button.Position = UDim2.fromScale(0.92, 0.89)
						button.Size = UDim2.fromScale(0.84, 0.16)
						button.Activated:Connect(function()
							local response = invoke(useBooster, booster.Id)
							if response and response.Success then
								refresh()
							elseif response then
								setStatus(response.Reason or "Booster could not be used.", false)
							end
						end)
						visibleRowCount += 1
					end
				end
			else
				subtitle.Text = "Counts include machines installed in your factory."
				setStatus(string.format("%d machine%s owned across %d type%s.", ownedCount, if ownedCount == 1 then "" else "s", #ids, if #ids == 1 then "" else "s"), nil)
				local rowIndex = 0
				local rollPool = MachineDefinitions.getRollPool()
				for _, section in ipairs(MACHINE_SECTIONS) do

					for _, machineId in ipairs(ids) do
						local definition = MachineDefinitions.get(machineId)
						if definition and definition.Category == section.Category and definition.Category == activeCategory then
							rowIndex += 1
							local count = available[machineId] or 0
							local actionText: string? = nil
							local action: (() -> ())? = nil
							if definition.Rollable and count > 0 then
								actionText = "Recycle"
								action = function()
									local response = invoke(sellMachine, machineId, 1)
									if response and response.Success then
										setStatus(string.format("Recycled one %s.", definition.DisplayName), true)
										refresh()
									elseif response then
										setStatus(response.Reason or "Machine could not be recycled.", false)
									end
								end
							end
							local odds = if definition.Rollable then EconomyRules.getMachineOddsLabel(machineId, rollPool) else nil
							local detail = string.format("%s %s · Owned %d · Placed %d · Available %d", definition.Rarity, definition.Category, totals[machineId] or 0, placed[machineId] or 0, count)
							if odds then detail ..= string.format(" · %s", odds) end
							local row = makeRow(machineId, rowIndex, false, count, placed[machineId] or 0, totals[machineId] or 0, actionText, count > 0, action, detail)
							if count > 0 then
								local place = makeButton(row, "PlaceButton", "Place")
								UI.asset(place.AmberBackground, "Action")
								place.TextColor3 = COLORS.Panel
								place.Position = UDim2.fromScale(0.08, 0.83)
								place.Size = UDim2.new(if actionText then 0.52 else 0.84, 0, 0, 44)
								place.Position = UDim2.new(0.08, 0, 1, -54)
								if actionText then
									row.ActionButton.Position = UDim2.new(0.61, 0, 1, -54)
									row.ActionButton.Size = UDim2.new(0.31, 0, 0, 44)
									row.ActionButton.TextSize = 9
								end
								if landscapeCompact then
									place.Position = UDim2.new(0.43, 0, 1, -54)
									place.Size = UDim2.new(if actionText then 0.31 else 0.53, 0, 0, 44)
									if actionText then
										row.ActionButton.Position = UDim2.new(0.75, 0, 1, -54)
										row.ActionButton.Size = UDim2.new(0.21, 0, 0, 44)
									end
								end
								place.Activated:Connect(function()
									mode = "AreaSelection"
									clearRows(list)
									title.Text = "Choose area"
									subtitle.Text = definition.Description
									for slot = 1, state.SlotCount do
										if FactoryLayout.expectedCategoryForSlot(slot) == definition.Category then
											local area = makeButton(list, "Area_" .. slot, FactoryLayout.getAreaLabel(slot))
											area.LayoutOrder = slot
											area.Activated:Connect(function() InventoryController.openPlacement(slot) end)
										end
									end
								end)
							end
							visibleRowCount += 1
						end
					end
				end
			end
		end

		if visibleRowCount == 0 then
			local empty = makeLabel(list, "EmptyInventory", if mode == "Placement" then "No owned machines of this type available yet." elseif activeTab == "Boosters" then "No boosters collected yet." else "No machines owned yet. Use Roll to get your first machine.")
			empty.Size = UDim2.new(1, -12, 0, 48)
			empty.TextColor3 = COLORS.Muted
			empty.TextSize = 12
			empty.LayoutOrder = 1
		end
	end

	openPanel = function(nextMode: string, slotIndex: number?, category: string?)
		if nextMode == "Placement" and not FactoryLayout.isEditableMachineSlot(slotIndex) then
			setStatus("Select a valid factory area first.", false)
			return
		end
		mode = nextMode
		activeCategory = if category and categoryTabs[category] then category else "Producer"
		activeTab = if category == "Booster" then "Boosters" else "Machines"
		targetSlot = if nextMode == "Placement" then slotIndex else nil
		panel.Visible = true
		refresh()
	end
	closePanel = function()
		panel.Visible = false
	end

	inventoryButton.Activated:Connect(function()
		if panel.Visible then
			closePanel()
		else
			openPanel("Inventory", nil)
		end
	end)
	machinesTab.Activated:Connect(function()
		activeTab = "Machines"
		activeCategory = "Producer"
		mode = "Inventory"
		render()
	end)
	for category, button in pairs(categoryTabs) do
		if category ~= "Producer" and category ~= "Booster" then
			button.Activated:Connect(function()
				activeCategory = category
				activeTab = "Machines"
				mode = "Inventory"
				render()
			end)
		end
	end
	boostersTab.Activated:Connect(function()
		activeTab = "Boosters"
		mode = "Inventory"
		render()
	end)
	closeButton.Activated:Connect(function()
		closePanel()
	end)

	local camera = workspace.CurrentCamera
	local function layout(viewportSize: Vector2)
		if screenGui.AbsoluteSize.X > 0 then viewportSize = screenGui.AbsoluteSize end
		local metrics = Layout.measure(viewportSize.X, viewportSize.Y)
		local scale = metrics.Scale
		local width = metrics.PanelWidth / scale
		local height = metrics.PanelHeight / scale
		landscapeCompact = metrics.Landscape
		panelScale.Scale = scale
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -8, 0, metrics.PanelTop)
		panel.Size = UDim2.fromOffset(width, height)
		inventoryButton.AnchorPoint = Vector2.new(0, 1)
		inventoryButton.Position = UDim2.new(0, 12, 1, -12)
		inventoryButton.Size = UDim2.fromOffset(metrics.InventoryWidth, metrics.InventoryHeight)
		local compact = metrics.Compact
		title.Position = UDim2.fromOffset(if compact then 58 else 76, 12)
		title.Size = UDim2.new(1, -110, 0, if compact then 34 else 44)
		title.TextSize = if compact then 22 else 30
		chest.Position = UDim2.fromOffset(20, 10)
		chest.Size = UDim2.fromOffset(if compact then 34 else 44, if compact then 34 else 44)
		closeButton.Position = UDim2.new(1, if compact then -54 else -110, 0, 10)
		closeButton.Size = UDim2.fromOffset(44, 44)
		subtitle.Visible = not compact
		subtitle.Position = UDim2.fromOffset(20, 58)
		subtitle.Size = UDim2.new(1, -40, 0, 20)
		status.Position = UDim2.fromOffset(20, if compact then height - 28 else 122)
		status.Size = UDim2.new(1, -40, 0, 20)
		status.TextSize = 11
		for index, key in ipairs({ "Producer", "Processor", "Seller", "Booster" }) do
			local button = categoryTabs[key]
			button.Position = UDim2.new((index - 1)/4, 12, 0, if compact then 48 else 80)
			button.Size = UDim2.new(0.25, -15, 0, 44)
			button.TextSize = if width < 470 then 10 else 14
			button.Caption.TextWrapped = false
			button.Caption.TextScaled = true
			local limit = button.Caption:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
			limit.MinTextSize = 8
			limit.MaxTextSize = button.TextSize
			limit.Parent = button.Caption
		end
		local listTop = if compact then 98 else 152
		list.Position = UDim2.fromOffset(18, listTop)
		list.Size = UDim2.new(1, -36, 1, -listTop - 36)
		local columns = metrics.Columns
		local cardWidth = (width - 48 - (columns - 1) * 8) / columns
		listLayout.CellSize = UDim2.new(1 / columns, -10, 0, if landscapeCompact then 174 else math.max(240, cardWidth * 1.55))
		if state then render() end
	end
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layout(screenGui.AbsoluteSize) end)

	if camera then
		layout(camera.ViewportSize)
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if workspace.CurrentCamera then
				layout(workspace.CurrentCamera.ViewportSize)
			end
		end)
	else
		layout(Vector2.new(1024, 768))
	end

	presentationEvent.OnClientEvent:Connect(function(eventName: string)
		if eventName == "InventoryChanged" then
			refresh()
		end
	end)

	refresh()
	openPanel("Inventory", nil)
end

return InventoryController
