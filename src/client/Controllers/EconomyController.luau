--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))
local EffectsController = require(script.Parent.EffectsController)

local EconomyController = {}
local started = false

local COLORS = {
	Panel = Color3.fromRGB(28, 24, 21),
	Button = Color3.fromRGB(46, 39, 34),
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
		local buyCapacity = remotes:WaitForChild("BuyCapacity") :: RemoteFunction
	local presentationEvent = remotes:WaitForChild("PresentationEvent") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EconomyHud"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
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

	local luckStatus = Instance.new("TextLabel")
	luckStatus.Name = "LuckStatus"
	luckStatus.BackgroundTransparency = 1
	luckStatus.TextColor3 = Color3.fromRGB(207, 176, 240)
	luckStatus.Font = Enum.Font.GothamBold
	luckStatus.TextSize = 11
	luckStatus.TextXAlignment = Enum.TextXAlignment.Left
	luckStatus.Parent = panel

	local result = Instance.new("TextLabel")
	result.BackgroundTransparency = 1
	result.TextColor3 = COLORS.Accent
	result.TextWrapped = false
	result.Font = Enum.Font.GothamBold
	result.TextScaled = true
	local resultTextLimit = Instance.new("UITextSizeConstraint")
	resultTextLimit.MinTextSize = 13
	resultTextLimit.MaxTextSize = 18
	resultTextLimit.Parent = result
	result.Parent = panel

	local rollDock = Instance.new("Frame")
	rollDock.Name = "RollDock"
	rollDock.AnchorPoint = Vector2.new(0.5, 1)
	rollDock.Position = UDim2.new(0.5, 0, 1, -14)
	rollDock.BackgroundColor3 = COLORS.Panel
	rollDock.BorderSizePixel = 0
	rollDock.Parent = screenGui
	local dockCorner = Instance.new("UICorner")
	dockCorner.CornerRadius = UDim.new(0, 16)
	dockCorner.Parent = rollDock
	local roll = createButton(rollDock, "Roll", "Roll")
	roll.Font = Enum.Font.GothamBlack
	roll.TextSize = 20
	roll.BackgroundColor3 = COLORS.Accent
	roll.TextColor3 = COLORS.Panel
	local rollCorner = Instance.new("UICorner")
	rollCorner.CornerRadius = UDim.new(0, 12)
	rollCorner.Parent = roll
	local capacity = createButton(panel, "Capacity", "Buy capacity")


	local state: any = nil
	local compact = false
	local cooldownEndAt = 0
	local rolling = false

	local function updateLuckStatus()
		local multiplier = if state then state.LuckMultiplier or 1 else 1
		local expiresAt = if state then state.LuckExpiresAt or 0 else 0
		local remaining = math.max(0, expiresAt - workspace:GetServerTimeNow())
		luckStatus.Visible = multiplier > 1 and remaining > 0
		luckStatus.Text = if luckStatus.Visible then string.format("Luck x%.1f · %ds", multiplier, math.ceil(remaining)) else ""
	end

	local function updateRollButton()
		local remaining = math.max(0, cooldownEndAt - os.clock())
		local ready = state ~= nil and state.DataReady == true
		roll.Text = if rolling then "ROLLING..." elseif not ready then "FACTORY LOADING" elseif remaining > 0 then string.format("READY IN %.1fs", remaining) else "Roll"
		roll.TextSize = if rolling then 16 else 20
		roll.TextWrapped = false
		roll.Active = ready and not rolling and remaining <= 0
		roll.AutoButtonColor = roll.Active
		roll.BackgroundColor3 = if roll.Active then COLORS.Accent else COLORS.Button
		roll.TextColor3 = if roll.Active then COLORS.Panel else COLORS.Text
	end

	local function syncCooldown(response: any)
		if response and type(response.RollCooldownRemaining) == "number" then
			cooldownEndAt = os.clock() + math.max(0, response.RollCooldownRemaining)
			updateRollButton()
		end
	end

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
		syncCooldown(response)
		if response and response.Success then
			state = response
			render()
			updateRollButton()
		else
			setStatus(response and response.Reason or "Economy is loading", false)
		end
	end

	render = function()
		if not state then
			return
		end
		status.Text = if state.DataReady then `Coins {state.Coins}  |  Slots {state.Capacity}/{state.MaxCapacity}  |  Machines {state.InventoryCount or 0}/{state.MaxInventoryMachines or 200}` else (state.DataError or "Factory data is loading")
		updateLuckStatus()
		capacity.Text = if state.CapacityCost then `Buy capacity · {state.CapacityCost} Coins` else "Capacity MAX"
	end

	roll.Activated:Connect(function()
		if rolling or not state or state.DataReady ~= true or os.clock() < cooldownEndAt then
			return
		end
		rolling = true
		updateRollButton()
		EffectsController.play("RollPending")
		local response = invoke(rollMachine)
		if response and response.Success then
			local definition = response.LastRoll and MachineDefinitions.get(response.LastRoll)
			local luckMultiplier = response.LastRollLuckMultiplier or 1
			local rollPool = EconomyRules.getLuckAdjustedRollPool(MachineDefinitions.getRollPool(), luckMultiplier)
			local odds = if definition and definition.Rollable then EconomyRules.getMachineOddsLabel(definition.Id, rollPool) else nil
			local machineName = definition and definition.DisplayName or response.LastRoll or "Machine"
			result.Text = if odds then string.format("Rolled: %s · %s", machineName, odds) else string.format("Rolled: %s", machineName)
			refresh(response)
			EffectsController.play("MachineRolled", { MachineId = response.LastRoll, Rarity = response.LastRarity, LuckMultiplier = luckMultiplier })
		else
			syncCooldown(response)
			setStatus(response and response.Reason or "Roll unavailable", false)
			EffectsController.play("RollRejected", { Reason = response and response.Reason or "Roll unavailable" })
		end
		task.delay(1.8, function()
			rolling = false
			updateRollButton()
		end)
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
		panel.Size = if compact then UDim2.fromOffset(panelWidth, 152) else UDim2.fromOffset(panelWidth, 180)
		panel.Position = if compactLandscape or compact then UDim2.new(1, -panelWidth - 8, 0, 8) else UDim2.new(1, -316, 0, 16)
		title.Position = UDim2.fromOffset(8, 8)
		title.Size = UDim2.new(1, -16, 0, if compact then 24 else 26)
		status.Position = UDim2.fromOffset(8, if compact then 34 else 36)
		status.Size = UDim2.new(1, -16, 0, if compact then 30 else 24)
		luckStatus.Position = UDim2.fromOffset(8, if compact then 64 else 62)
		luckStatus.Size = UDim2.new(1, -16, 0, 16)
		result.Position = UDim2.fromOffset(8, if compact then 82 else 84)
		result.Size = UDim2.new(1, -16, 0, if compact then 20 else 24)
		capacity.Position = UDim2.fromOffset(8, if compact then 106 else 130)
		capacity.Size = UDim2.fromOffset(panelWidth - 16, if compact then 36 else 34)
		rollDock.Size = UDim2.fromOffset(if compact then math.min(268, viewportWidth - 24) else 320, 72)
		roll.Position = UDim2.fromOffset(8, 8)
		roll.Size = UDim2.new(1, -16, 1, -16)
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
	setStatus("Roll for free; production funds capacity upgrades.", nil)
	refresh(nil)
	presentationEvent.OnClientEvent:Connect(function(eventName: string)
		if eventName == "InventoryChanged" then
			refresh(nil)
		end
	end)
	task.spawn(function()
		while screenGui.Parent do
			updateRollButton()
			updateLuckStatus()
			task.wait(0.25)
		end
	end)
end

return EconomyController
