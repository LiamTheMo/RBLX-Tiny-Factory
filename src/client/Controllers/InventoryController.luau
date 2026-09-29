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

local InventoryController = {}
local started = false
local openPanel: ((string, number?) -> ())? = nil
local closePanel: (() -> ())? = nil

local COLORS = {
	Panel = Color3.fromRGB(30, 27, 35),
	Row = Color3.fromRGB(46, 42, 52),
	Button = Color3.fromRGB(68, 61, 77),
	Accent = Color3.fromRGB(255, 210, 128),
	Text = Color3.fromRGB(248, 245, 250),
	Muted = Color3.fromRGB(195, 190, 204),
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
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function InventoryController.openInventory()
	if openPanel then
		openPanel("Inventory", nil)
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
	local presentationEvent = remotes:WaitForChild("PresentationEvent") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FactoryInventoryHud"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui

	local inventoryButton = makeButton(screenGui, "InventoryButton", "Inventory")
	inventoryButton.Size = UDim2.fromOffset(136, 40)
	inventoryButton.BackgroundColor3 = COLORS.Panel
	inventoryButton.TextSize = 14

	local panel = Instance.new("Frame")
	panel.Name = "MachinePanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 16)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(120, 108, 137)
	panelStroke.Transparency = 0.35
	panelStroke.Thickness = 1
	panelStroke.Parent = panel

	local title = makeLabel(panel, "PanelTitle", "Inventory")
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -76, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLORS.Accent
	title.TextSize = 19

	local closeButton = makeButton(panel, "CloseButton", "×")
	closeButton.Position = UDim2.new(1, -50, 0, 9)
	closeButton.Size = UDim2.fromOffset(38, 34)
	closeButton.TextSize = 20

	local subtitle = makeLabel(panel, "Subtitle", "")
	subtitle.Position = UDim2.fromOffset(18, 42)
	subtitle.Size = UDim2.new(1, -36, 0, 22)
	subtitle.TextColor3 = COLORS.Muted
	subtitle.TextSize = 12

	local status = makeLabel(panel, "Status", "Loading factory inventory...")
	status.Position = UDim2.fromOffset(18, 66)
	status.Size = UDim2.new(1, -36, 0, 24)
	status.TextSize = 12

	local list = Instance.new("ScrollingFrame")
	list.Name = "MachineList"
	list.Position = UDim2.fromOffset(12, 96)
	list.Size = UDim2.new(1, -24, 1, -108)
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
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local state: any = nil
	local mode = "Inventory"
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
		local rarity = definition and definition.Rarity or "Unknown"
		local name = definition and definition.DisplayName or machineId
		local rarityColor = rarityColors[rarity] or COLORS.Text

		local row = Instance.new("Frame")
		row.Name = if isPlacement then string.format("Place_%s_%d", machineId, rowIndex) else string.format("Owned_%s", machineId)
		row.LayoutOrder = rowIndex
		row.Size = UDim2.new(1, -8, 0, if isPlacement then 78 else 88)
		row.BackgroundColor3 = COLORS.Row
		row.BorderSizePixel = 0
		row.Parent = list
		addCorner(row, 10)

		local nameLabel = makeLabel(row, "MachineName", name)
		nameLabel.Position = UDim2.fromOffset(10, 5)
		nameLabel.Size = if actionText then UDim2.new(1, -112, 0, 21) else UDim2.new(1, -20, 0, 21)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextColor3 = rarityColor
		nameLabel.TextSize = 14
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local countText = if detailOverride then detailOverride elseif isPlacement
			then string.format("%s · Available ×%d", rarity, availableCount)
			else string.format("%s %s · Owned %d · Placed %d · Available %d", rarity, definition and definition.Category or "Machine", totalCount, placedCount, availableCount)
		local details = makeLabel(row, "MachineDetails", countText)
		details.Position = UDim2.fromOffset(10, 27)
		details.Size = if actionText then UDim2.new(1, -112, 0, 20) else UDim2.new(1, -20, 0, 20)
		details.TextColor3 = COLORS.Muted
		details.TextSize = 11
		details.TextTruncate = Enum.TextTruncate.AtEnd

		local description = makeLabel(row, "Description", definition and definition.Description or "This item is not in the current machine catalog.")
		description.Position = UDim2.fromOffset(10, 48)
		description.Size = if actionText then UDim2.new(1, -112, 0, if isPlacement then 24 else 33) else UDim2.new(1, -20, 0, if isPlacement then 24 else 33)
		description.TextColor3 = COLORS.Muted
		description.TextSize = 10
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.TextTruncate = Enum.TextTruncate.AtEnd

		if actionText then
			local button = makeButton(row, "ActionButton", actionText)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -8, 0.5, 0)
			button.Size = UDim2.fromOffset(94, 34)
			button.Active = actionEnabled
			button.AutoButtonColor = actionEnabled
			button.BackgroundColor3 = if actionEnabled then COLORS.Button else Color3.fromRGB(66, 63, 70)
			button.TextColor3 = if actionEnabled then COLORS.Text else COLORS.Muted
			button.Activated:Connect(function()
				if actionEnabled and action then
					action()
				end
			end)
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

		local ids, totals, placed, available = getCounts()
		local ownedCount = 0
		for _, count in pairs(totals) do
			ownedCount += count
		end
		inventoryButton.Text = string.format("Inventory · %d", ownedCount)
		local visibleRowCount = 0

		if mode == "Placement" and targetSlot then
			local placementSlot = targetSlot :: number
			title.Text = string.format("Place in Area %d", placementSlot)
			subtitle.Text = "Choose an owned machine. The seller must remain the last machine on the route."
			local currentId = state.Layout[placementSlot]
			local currentDefinition = if currentId and currentId ~= "" then MachineDefinitions.get(currentId) else nil
			local currentName = if currentId and currentId ~= "" then (currentDefinition and currentDefinition.DisplayName or currentId) else "Empty"
			local currentMachineName = currentDefinition and currentDefinition.DisplayName or currentName
			setStatus(string.format("Area %d · %s · Capacity %d", placementSlot, currentName, state.Capacity), nil)

			local layout = normalizeLayout()
			local rowIndex = 0
			for _, machineId in ipairs(ids) do
				local count = available[machineId] or 0
				if count > 0 then
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
				if sourceId and sourceSlot ~= placementSlot then
					local candidate, moveError = PlacementRules.createMoveLayout(layout, sourceSlot, placementSlot, state.Capacity)
					rowIndex += 1
					local sourceDefinition = MachineDefinitions.get(sourceId)
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
			subtitle.Text = "Counts include machines installed in your factory."
			setStatus(string.format("%d machine%s owned across %d type%s.", ownedCount, if ownedCount == 1 then "" else "s", #ids, if #ids == 1 then "" else "s"), nil)
			local rowIndex = 0
			local rollPool = MachineDefinitions.getRollPool()
			for _, machineId in ipairs(ids) do
				rowIndex += 1
				local definition = MachineDefinitions.get(machineId)
				local count = available[machineId] or 0
				local actionText: string? = nil
				local action: (() -> ())? = nil
				if definition and definition.Rollable and count > 0 then
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
				local odds = if definition and definition.Rollable then EconomyRules.getMachineOddsLabel(machineId, rollPool) else nil
				local detail = string.format("%s %s · Owned %d · Placed %d · Available %d", definition and definition.Rarity or "Unknown", definition and definition.Category or "Machine", totals[machineId] or 0, placed[machineId] or 0, count)
				if odds then
					detail ..= string.format(" · %s", odds)
				end
				makeRow(machineId, rowIndex, false, count, placed[machineId] or 0, totals[machineId] or 0, actionText, count > 0, action, detail)
				visibleRowCount += 1
			end
		end

		if visibleRowCount == 0 then
			local empty = makeLabel(list, "EmptyInventory", if mode == "Placement" then "No owned machines can be placed here yet." else "No machines owned yet. Use Roll to get your first machine.")
			empty.Size = UDim2.new(1, -12, 0, 48)
			empty.TextColor3 = COLORS.Muted
			empty.TextSize = 12
			empty.LayoutOrder = 1
		end
	end

	openPanel = function(nextMode: string, slotIndex: number?)
		if nextMode == "Placement" and not FactoryLayout.isEditableMachineSlot(slotIndex) then
			setStatus("Select a valid factory area first.", false)
			return
		end
		mode = nextMode
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
	closeButton.Activated:Connect(function()
		closePanel()
	end)

	local camera = workspace.CurrentCamera
	local function layout(viewportSize: Vector2)
		local compact = viewportSize.X < 760 or (UserInputService.TouchEnabled and viewportSize.X < 1000)
		inventoryButton.Position = if compact then UDim2.fromOffset(8, 170) else UDim2.fromOffset(16, 16)
		local width = math.max(280, math.min(620, viewportSize.X - 28))
		local height = math.max(240, math.min(520, viewportSize.Y - 28))
		panel.Size = UDim2.fromOffset(width, height)
		title.Position = UDim2.fromOffset(18, 12)
		title.Size = UDim2.new(1, -76, 0, 28)
		closeButton.Position = UDim2.new(1, -50, 0, 9)
		subtitle.Position = UDim2.fromOffset(18, 42)
		subtitle.Size = UDim2.new(1, -36, 0, 22)
		status.Position = UDim2.fromOffset(18, 66)
		status.Size = UDim2.new(1, -36, 0, 24)
		list.Position = UDim2.fromOffset(12, 96)
		list.Size = UDim2.new(1, -24, 1, -108)
	end
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
end

return InventoryController
