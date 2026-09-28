--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))

local EconomyController = {}
local started = false

local COLORS = {
	Panel = Color3.fromRGB(28, 24, 21),
	Button = Color3.fromRGB(46, 39, 34),
	Selected = Color3.fromRGB(112, 77, 34),
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
	button.TextSize = 12
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Parent = parent
	return button
end

local function clearDynamicChildren(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

function EconomyController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Factory")
	local getState = remotes:WaitForChild("GetEconomyState") :: RemoteFunction
	local rollMachine = remotes:WaitForChild("RollMachine") :: RemoteFunction
	local sellMachine = remotes:WaitForChild("SellMachine") :: RemoteFunction
	local buyCapacity = remotes:WaitForChild("BuyCapacity") :: RemoteFunction

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EconomyHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "EconomyPanel"
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Factory economy"
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

	local result = Instance.new("TextLabel")
	result.BackgroundTransparency = 1
	result.TextColor3 = COLORS.Accent
	result.TextWrapped = true
	result.Font = Enum.Font.GothamBold
	result.TextSize = 13
	result.Parent = panel

	local roll = createButton(panel, "Roll", "Roll machine")
	local capacity = createButton(panel, "Capacity", "Buy capacity")

	local inventoryTitle = Instance.new("TextLabel")
	inventoryTitle.BackgroundTransparency = 1
	inventoryTitle.Text = "Inventory — tap an item to sell one"
	inventoryTitle.TextColor3 = COLORS.Text
	inventoryTitle.Font = Enum.Font.GothamBold
	inventoryTitle.TextSize = 11
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
	inventoryLayout.Padding = UDim.new(0, 3)
	inventoryLayout.Parent = inventoryList

	local state: any = nil
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
	local function refresh(responseOverride: any)
		local response = responseOverride or invoke(getState)
		if response and response.Success then
			state = response
			render()
		else
			setStatus(response and response.Reason or "Economy is loading", false)
		end
	end

	render = function()
		if not state then
			return
		end
		status.Text = `Coins: {state.Coins}  |  Roll: {state.RollCost or "MAX"}  |  Capacity: {state.Capacity}/{state.MaxCapacity}`
		clearDynamicChildren(inventoryList)
		local count = 0
		for machineId, quantity in pairs(state.Inventory or {}) do
			if quantity > 0 then
				count += 1
				local definition = MachineDefinitions.get(machineId)
				local button = createButton(inventoryList, `Sell_{machineId}`, `Sell {definition and definition.DisplayName or machineId} ×{quantity}`)
				button.Size = UDim2.new(1, -6, 0, if compact then 28 else 32)
				button.TextXAlignment = Enum.TextXAlignment.Left
				button.Activated:Connect(function()
					local response = invoke(sellMachine, machineId, 1)
					if response and response.Success then
						setStatus(`Sold one {definition and definition.DisplayName or machineId}.`, true)
						refresh(response)
					end
				end)
			end
		end
		if count == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Text = "Inventory is empty. Roll a machine to get another choice."
			empty.TextColor3 = Color3.fromRGB(190, 180, 170)
			empty.Font = Enum.Font.Gotham
			empty.TextSize = 11
			empty.TextWrapped = true
			empty.Size = UDim2.new(1, -6, 0, 28)
			empty.Parent = inventoryList
		end
		inventoryList.CanvasSize = UDim2.fromOffset(0, inventoryLayout.AbsoluteContentSize.Y)
	end

	roll.Activated:Connect(function()
		local response = invoke(rollMachine)
		if response and response.Success then
			local definition = response.LastRoll and MachineDefinitions.get(response.LastRoll)
			result.Text = `Rolled: {definition and definition.DisplayName or response.LastRoll or "Machine"} ({response.LastRarity or "Unknown"})`
			setStatus("Machine added to inventory.", true)
			refresh(response)
		end
	end)

	capacity.Activated:Connect(function()
		local response = invoke(buyCapacity)
		if response and response.Success then
			setStatus(`Capacity expanded to {response.Capacity}.`, true)
			refresh(response)
		end
	end)

	local function layout(viewportWidth: number, viewportHeight: number)
		compact = viewportWidth < 760 or (UserInputService.TouchEnabled and viewportWidth < 1000)
		local compactLandscape = compact and viewportWidth > viewportHeight
		local panelWidth = 300
		if compact then
			local widthRatio = if compactLandscape then 0.34 else 0.68
			panelWidth = math.floor(math.clamp(viewportWidth * widthRatio, 232, 272))
			panelWidth = math.min(panelWidth, math.max(184, viewportWidth - 16))
		end
		panel.Size = if compact then UDim2.fromOffset(panelWidth, 204) else UDim2.fromOffset(panelWidth, 350)
		panel.Position = if compactLandscape then UDim2.fromOffset(8, 8) elseif compact then UDim2.fromOffset(8, 8) else UDim2.new(1, -316, 0, 16)
		title.Position = UDim2.fromOffset(8, 8)
		title.Size = UDim2.new(1, -16, 0, if compact then 24 else 26)
		status.Position = UDim2.fromOffset(8, if compact then 34 else 36)
		status.Size = UDim2.new(1, -16, 0, if compact then 34 else 24)
		result.Position = UDim2.fromOffset(8, if compact then 70 else 62)
		result.Size = UDim2.new(1, -16, 0, if compact then 20 else 24)
		local buttonY = if compact then 94 else 130
		roll.Position = UDim2.fromOffset(8, if compact then 94 else 90)
		capacity.Position = if compact
			then UDim2.fromOffset(12 + (panelWidth - 24) / 2, buttonY)
			else UDim2.fromOffset(8, 130)
		roll.Size = if compact
			then UDim2.fromOffset((panelWidth - 24) / 2, 38)
			else UDim2.fromOffset(284, 34)
		capacity.Size = if compact
			then UDim2.fromOffset((panelWidth - 24) / 2, 38)
			else UDim2.fromOffset(284, 34)
		inventoryTitle.Position = UDim2.fromOffset(8, if compact then 138 else 174)
		inventoryTitle.Size = UDim2.new(1, -16, 0, 18)
		inventoryList.Position = UDim2.fromOffset(8, if compact then 158 else 196)
		inventoryList.Size = UDim2.new(1, -16, 0, if compact then 38 else 142)
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
	setStatus("Production funds rolls and capacity upgrades.", nil)
	refresh(nil)
end

return EconomyController
