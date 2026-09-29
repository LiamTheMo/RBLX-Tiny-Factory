--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))

local BuildController = {}
local started = false

local COLORS = {
	Panel = Color3.fromRGB(28, 24, 21),
	Button = Color3.fromRGB(46, 39, 34),
	Selected = Color3.fromRGB(112, 77, 34),
	Locked = Color3.fromRGB(54, 51, 48),
	Good = Color3.fromRGB(140, 235, 150),
	Bad = Color3.fromRGB(255, 150, 120),
	Text = Color3.fromRGB(255, 255, 255),
	Accent = Color3.fromRGB(255, 194, 66),
}

local function createButton(parent: Instance, name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.BackgroundColor3 = COLORS.Button
	button.TextColor3 = COLORS.Text
	button.Font = Enum.Font.Gotham
	button.TextSize = 13
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Parent = parent
	return button
end

local function clearDynamicChildren(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function BuildController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local factoryRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Factory")
	local getFactoryState = factoryRemotes:WaitForChild("GetFactoryState") :: RemoteFunction
	local placeMachine = factoryRemotes:WaitForChild("PlaceMachine") :: RemoteFunction
	local removeMachine = factoryRemotes:WaitForChild("RemoveMachine") :: RemoteFunction
	local moveMachine = factoryRemotes:WaitForChild("MoveMachine") :: RemoteFunction
	local presentationEvent = factoryRemotes:WaitForChild("PresentationEvent") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "BuildPanel"
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Build factory"
	title.TextColor3 = COLORS.Accent
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.TextColor3 = COLORS.Text
	status.TextWrapped = true
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.Parent = panel

	local inventoryTitle = Instance.new("TextLabel")
	inventoryTitle.BackgroundTransparency = 1
	inventoryTitle.Text = "Inventory — select a machine"
	inventoryTitle.TextColor3 = COLORS.Text
	inventoryTitle.Font = Enum.Font.GothamBold
	inventoryTitle.TextSize = 12
	inventoryTitle.TextXAlignment = Enum.TextXAlignment.Left
	inventoryTitle.Parent = panel

	local inventoryList = Instance.new("ScrollingFrame")
	inventoryList.Name = "InventoryList"
	inventoryList.BackgroundTransparency = 1
	inventoryList.BorderSizePixel = 0
	inventoryList.ScrollBarThickness = 5
	inventoryList.CanvasSize = UDim2.fromScale(0, 0)
	inventoryList.Parent = panel
	local inventoryLayout = Instance.new("UIListLayout")
	inventoryLayout.Padding = UDim.new(0, 4)
	inventoryLayout.Parent = inventoryList

	local slotsTitle = Instance.new("TextLabel")
	slotsTitle.BackgroundTransparency = 1
	slotsTitle.Text = "Factory slots"
	slotsTitle.TextColor3 = COLORS.Text
	slotsTitle.Font = Enum.Font.GothamBold
	slotsTitle.TextSize = 12
	slotsTitle.TextXAlignment = Enum.TextXAlignment.Left
	slotsTitle.Parent = panel

	local slotsList = Instance.new("ScrollingFrame")
	slotsList.Name = "SlotsList"
	slotsList.BackgroundTransparency = 1
	slotsList.Parent = panel
	slotsList.AutomaticCanvasSize = Enum.AutomaticSize.X
	slotsList.CanvasSize = UDim2.new(0, 0, 1, 0)
	slotsList.Active = true
	slotsList.ScrollingDirection = Enum.ScrollingDirection.X
	slotsList.ScrollBarThickness = if UserInputService.TouchEnabled then 0 else 4
	slotsList.ClipsDescendants = true
	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.FillDirection = Enum.FillDirection.Horizontal
	slotsLayout.Padding = UDim.new(0, 4)
	slotsLayout.Parent = slotsList

	local remove = createButton(panel, "Remove", "Remove selected")
	local cancel = createButton(panel, "Cancel", "Cancel")
	local orientation = createButton(panel, "Orientation", "Direction fixed")

	local state: any = nil
	local selectedMachine: string? = nil
	local sourceSlot: number? = nil
	local compact = false

	local function setStatus(message: string, good: boolean?)
		status.Text = message
		status.TextColor3 = if good == true then COLORS.Good elseif good == false then COLORS.Bad else COLORS.Text
	end

	local function invoke(remote: RemoteFunction, ...: any): any
		local arguments = { ... }
		local success, response = pcall(function()
			return remote:InvokeServer(table.unpack(arguments))
		end)
		if not success then
			setStatus("Server request failed. Try again.", false)
			return nil
		end
		return response
	end

	local render: () -> ()
	local function refresh()
		local response = invoke(getFactoryState)
		if response and response.Success then
			state = response
			render()
		else
			setStatus(response and response.Reason or "Factory is loading", false)
		end
	end

	local function selectMachine(machineId: string)
		selectedMachine = machineId
		sourceSlot = nil
		local definition = MachineDefinitions.get(machineId)
		setStatus(`Selected {definition and definition.DisplayName or machineId}. Choose a slot.`, nil)
		render()
	end

	local function handleSlot(slotIndex: number)
		if not state then
			return
		end
		local locked = slotIndex > 1 and slotIndex < state.SlotCount and slotIndex > state.Capacity + 1
		if locked then
			setStatus("That slot is locked. Buy factory capacity first.", false)
			return
		end
		local existing = state.Layout[slotIndex]
		if selectedMachine then
			local response = invoke(placeMachine, selectedMachine, slotIndex, existing ~= "")
			if response and response.Success then
				selectedMachine = nil
				setStatus("Machine placed. The route updated.", true)
				refresh()
			end
			return
		end
		if sourceSlot then
			if sourceSlot == slotIndex then
				setStatus("Move cancelled.", nil)
				sourceSlot = nil
				render()
				return
			end
			local response = invoke(moveMachine, sourceSlot, slotIndex)
			if response and response.Success then
				sourceSlot = nil
				setStatus("Machine moved. The route updated.", true)
				refresh()
			end
			return
		end
		if existing ~= "" and slotIndex > 1 and slotIndex < state.SlotCount then
			sourceSlot = slotIndex
			setStatus("Source selected. Choose an empty destination slot.", nil)
			render()
		else
			setStatus("Select a machine from inventory first.", nil)
		end
	end

	render = function()
		if not state then
			return
		end
		clearDynamicChildren(inventoryList)
		clearDynamicChildren(slotsList)

		local inventoryCount = 0
		for machineId, quantity in pairs(state.Inventory or {}) do
			if quantity > 0 then
				inventoryCount += 1
				local definition = MachineDefinitions.get(machineId)
				local button = createButton(inventoryList, `Machine_{machineId}`, `{definition and definition.DisplayName or machineId} ×{quantity}`)
				button.Size = UDim2.new(1, -8, 0, if compact then 30 else 34)
				button.TextXAlignment = Enum.TextXAlignment.Left
				button:SetAttribute("Description", definition and definition.Description or "")
				if selectedMachine == machineId then
					button.BackgroundColor3 = COLORS.Selected
				end
				button.Activated:Connect(function()
					selectMachine(machineId)
				end)
			end
		end
		if inventoryCount == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Text = "No rolled machines yet — use ROLL FREE at the bottom."
			empty.TextColor3 = Color3.fromRGB(190, 180, 170)
			empty.Font = Enum.Font.Gotham
			empty.TextSize = 11
			empty.TextWrapped = true
			empty.Size = UDim2.new(1, -8, 0, 30)
			empty.Parent = inventoryList
		end
		inventoryList.CanvasSize = UDim2.fromOffset(0, inventoryLayout.AbsoluteContentSize.Y)

		for slotIndex = 1, state.SlotCount do
			local machineId = state.Layout[slotIndex]
			local definition = if machineId ~= "" then MachineDefinitions.get(machineId) else nil
			local locked = slotIndex > 1 and slotIndex < state.SlotCount and slotIndex > state.Capacity + 1
			local text = if locked then `Slot {slotIndex}\nLOCKED` elseif definition then `Slot {slotIndex}\n{definition.DisplayName}` else `Slot {slotIndex}\nEmpty`
			local button = createButton(slotsList, `Slot_{slotIndex}`, text)
			button.Size = UDim2.fromOffset(if compact then 52 else 62, if compact then 48 else 54)
			button.BackgroundColor3 = if locked then COLORS.Locked elseif sourceSlot == slotIndex then COLORS.Selected else COLORS.Button
			button.TextSize = 10
			button.Activated:Connect(function()
				handleSlot(slotIndex)
			end)
		end
	end

	remove.Activated:Connect(function()
		if sourceSlot then
			local response = invoke(removeMachine, sourceSlot)
			if response and response.Success then
				sourceSlot = nil
				setStatus("Machine removed to inventory.", true)
				refresh()
			end
		else
			setStatus("Select a processor slot to remove it.", nil)
		end
	end)
	cancel.Activated:Connect(function()
		selectedMachine = nil
		sourceSlot = nil
		setStatus("Selection cleared.", nil)
		render()
	end)
	orientation.Activated:Connect(function()
		setStatus("This v1 route runs left to right; orientation is fixed by design.", nil)
	end)

	local function layout(viewportWidth: number, viewportHeight: number)
		compact = viewportWidth < 760 or (UserInputService.TouchEnabled and viewportWidth < 1000)
		local compactLandscape = compact and viewportWidth > viewportHeight
		local panelWidth = 360
		if compact then
			local widthRatio = if compactLandscape then 0.34 else 0.68
			panelWidth = math.floor(math.clamp(viewportWidth * widthRatio, 232, 272))
			panelWidth = math.min(panelWidth, math.max(184, viewportWidth - 16))
		end
		panel.Size = if compact then UDim2.fromOffset(panelWidth, 256) else UDim2.fromOffset(panelWidth, 380)
		panel.Position = if compactLandscape
			then UDim2.new(1, -panelWidth - 8, 0, 8)
			elseif compact then UDim2.fromOffset(8, 214)
			else UDim2.fromOffset(16, 188)
		title.Position = UDim2.fromOffset(8, 8)
		title.Size = UDim2.new(1, -16, 0, if compact then 24 else 28)
		status.Position = UDim2.fromOffset(8, if compact then 34 else 38)
		status.Size = UDim2.new(1, -16, 0, if compact then 30 else 30)
		inventoryTitle.Position = UDim2.fromOffset(8, if compact then 68 else 72)
		inventoryTitle.Size = UDim2.new(1, -16, 0, if compact then 18 else 20)
		inventoryList.Position = UDim2.fromOffset(8, if compact then 86 else 94)
		inventoryList.Size = UDim2.new(1, -16, 0, if compact then 48 else 92)
		slotsTitle.Position = UDim2.fromOffset(8, if compact then 138 else 190)
		slotsTitle.Size = UDim2.new(1, -16, 0, 18)
		slotsList.Position = UDim2.fromOffset(8, if compact then 158 else 212)
		slotsList.Size = UDim2.new(1, -16, 0, if compact then 42 else 58)
		local actionY = if compact then 206 else 286
		for index, button in ipairs({ remove, cancel, orientation }) do
			button.Position = UDim2.new((index - 1) / 3, 6, 0, actionY)
			button.Size = UDim2.new(1 / 3, -10, 0, if compact then 38 else 34)
		end
		render()
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			layout(camera.ViewportSize.X, camera.ViewportSize.Y)
		end)
		layout(camera.ViewportSize.X, camera.ViewportSize.Y)
	else
		layout(1000, 800)
	end
	setStatus("Select a machine or a processor slot to begin.", nil)
	refresh()
	presentationEvent.OnClientEvent:Connect(function(eventName: string)
		if eventName == "InventoryChanged" then
			refresh()
		end
	end)
end

return BuildController
