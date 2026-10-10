--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormatter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NumberFormatter"))

local EffectsController = require(script.Parent.EffectsController)

local UI = require(script.Parent.AmberUI)
local Layout = require(ReplicatedStorage.Shared.AmberLayout)
local EconomyController = {}
local started = false

local COLORS = {
	Panel = Color3.fromRGB(28, 24, 21),
	Button = Color3.fromRGB(46, 39, 34),
	Good = Color3.fromRGB(140, 235, 150),
	Bad = Color3.fromRGB(255, 150, 120),
	Text = UI.Text,
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
	UI.skin(button, "Action")
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
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "EconomyPanel"
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	UI.skin(panel, "Panel")
	panel.Visible = false
	panel.ZIndex = 5
	local settings = createButton(screenGui, "Settings", "")
	UI.asset(settings.AmberBackground, "Settings")
	settings.Size = UDim2.fromOffset(56, 56)
	settings.Position = UDim2.new(1, -70, 0, 12)
	local settingsGui = Instance.new("ScreenGui")
	settingsGui.Name = "AmberSettings"
	settingsGui.ResetOnSpawn = false
	settingsGui.DisplayOrder = 18
	settingsGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	settingsGui.Parent = playerGui
	panel.Parent = settingsGui
	settings.Parent = settingsGui
	settings.Activated:Connect(function() panel.Visible = not panel.Visible end)
	local coins = Instance.new("Frame")
	coins.Name = "CoinHud"
	coins.Parent = screenGui
	UI.skin(coins, "Coins")
	local coinIcon = UI.image(coins, "Coin")
	coinIcon.Position = UDim2.fromScale(0.08, 0.2)
	coinIcon.Size = UDim2.fromScale(0.23, 0.6)
	local balance = UI.label(coins, "Balance", "Loading...")
	balance.Position = UDim2.fromScale(0.33, 0.2)
	balance.Size = UDim2.fromScale(0.57, 0.6)
	balance.TextScaled = true

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Settings & capacity"
	title.TextColor3 = COLORS.Accent
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "EconomyStatus"
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

	local rollDock = Instance.new("Frame")
	rollDock.Name = "RollDock"
	rollDock.AnchorPoint = Vector2.new(0.5, 1)
	rollDock.Position = UDim2.new(0.5, 0, 1, -14)
	rollDock.BackgroundTransparency = 1
	rollDock.BorderSizePixel = 0
	rollDock.Parent = screenGui
	local roll = createButton(rollDock, "Roll", "Roll")
	roll.Font = Enum.Font.GothamBlack
	roll.TextSize = 30
	UI.asset(roll.AmberBackground, "Roll")
	local dice = UI.image(roll, "Dice")
	dice.Position = UDim2.fromScale(0.19, 0.27)
	dice.Size = UDim2.fromScale(0.18, 0.45)
	UI.caption(roll, 0.32)
	roll.BackgroundColor3 = COLORS.Accent
	roll.TextColor3 = COLORS.Panel
	local rollCorner = Instance.new("UICorner")
	rollCorner.CornerRadius = UDim.new(0, 12)
	rollCorner.Parent = roll
	local capacity = createButton(panel, "Capacity", "Buy capacity")


	local state: any = nil
	local cooldownEndAt = 0
	local rolling = false

	local function updateLuckStatus()
		local multiplier = if state then state.LuckMultiplier or 1 else 1
		local expiresAt = if state then state.LuckExpiresAt or 0 else 0
		local remaining = math.max(0, expiresAt - workspace:GetServerTimeNow())
		luckStatus.Visible = multiplier > 1 and remaining > 0
		luckStatus.Text = if luckStatus.Visible then string.format("Luck x%.2f · %ds", multiplier, math.ceil(remaining)) else ""
	end

	local function updateRollButton()
		local remaining = math.max(0, cooldownEndAt - os.clock())
		local ready = state ~= nil and state.DataReady == true
		roll.Text = if rolling then "ROLLING..." elseif not ready then "FACTORY LOADING" elseif remaining > 0 then string.format("READY IN %.2fs", remaining) else "Roll"
		roll.TextSize = if roll.Text == "Roll" then 30 else 13
		roll.TextWrapped = false
		roll.Active = ready and not rolling and remaining <= 0
		roll.AutoButtonColor = roll.Active
		roll.BackgroundTransparency = 1
		roll.AmberBackground.ImageTransparency = if rolling then 0.5 elseif roll.Active then 0 else 0.3
		dice.Visible = roll.Text == "Roll"
		roll.BackgroundColor3 = if roll.Active then COLORS.Accent else COLORS.Button
		roll.TextColor3 = UI.Text
		roll.TextStrokeColor3 = Color3.fromRGB(20, 24, 32)
		roll.TextStrokeTransparency = if rolling then 0.2 else 1
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
			local ready = player:GetAttribute("FactoryDataReady")
			if type(ready) == "boolean" then state.DataReady = ready end
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
		status.Text = if state.DataReady then `Coins {NumberFormatter.format(state.Coins)}  |  Slots {state.Capacity}/{state.MaxCapacity}  |  Machines {state.InventoryCount or 0}/{state.MaxInventoryMachines or 200}` else (state.DataError or "Factory data is loading")
		balance.Text = NumberFormatter.format(state.Coins)
		updateLuckStatus()
		capacity.Text = if state.CapacityCost then `Buy capacity · {NumberFormatter.format(state.CapacityCost)} Coins` else "Capacity MAX"
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
			local luckMultiplier = response.LastRollLuckMultiplier or 1
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
		local safeSize = screenGui.AbsoluteSize
		if safeSize.X > 0 and safeSize.Y > 0 then viewportWidth = safeSize.X; viewportHeight = safeSize.Y end
		local metrics = Layout.measure(viewportWidth, viewportHeight)
		coins.Position = UDim2.fromOffset(12, 8)
		coins.Size = UDim2.fromOffset(metrics.CoinWidth, metrics.CoinHeight)
		settings.Position = UDim2.fromOffset(metrics.SettingsX, 8)
		settings.Size = UDim2.fromOffset(math.max(44, metrics.SettingsSize), math.max(44, metrics.SettingsSize))

		panel.Size = UDim2.fromOffset(math.min(330, viewportWidth - 24), 228)
		panel.Position = UDim2.new(1, -math.min(330, viewportWidth - 24) - 12, 0, 76)
		title.Position = UDim2.fromOffset(16, 16)
		title.Size = UDim2.new(1, -32, 0, 26)
		status.Position = UDim2.fromOffset(16, 56)
		status.Size = UDim2.new(1, -32, 0, 68)
		luckStatus.Position = UDim2.fromOffset(16, 128)
		luckStatus.Size = UDim2.new(1, -32, 0, 24)
		capacity.Position = UDim2.fromOffset(16, 164)
		capacity.Size = UDim2.new(1, -32, 0, 48)
		rollDock.Size = UDim2.fromOffset(metrics.RollWidth, metrics.RollHeight)
		rollDock.Position = UDim2.new(0, metrics.RollCenter, 1, -8)
		roll.Position = UDim2.fromScale(0, 0)
		roll.Size = UDim2.fromScale(1, 1)
		render()
	end

	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layout(screenGui.AbsoluteSize.X, screenGui.AbsoluteSize.Y)
	end)
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
	player:GetAttributeChangedSignal("FactoryCoins"):Connect(function()
		local balance = player:GetAttribute("FactoryCoins")
		if state and type(balance) == "number" then state.Coins = balance; render() end
	end)
	for _, attribute in ipairs({ "FactoryDataReady", "FactoryDataError" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if state then
				state.DataReady = player:GetAttribute("FactoryDataReady") == true
				state.DataError = player:GetAttribute("FactoryDataError")
				render()
				updateRollButton()
			end
		end)
	end
	presentationEvent.OnClientEvent:Connect(function(eventName: string, payload: any)
		if eventName == "ItemSold" and state and type(payload.Balance) == "number" then
			state.Coins = payload.Balance
			render()
		elseif eventName == "InventoryChanged" then
			refresh(nil)
		end
	end)
	refresh(nil)
	task.spawn(function()
		while screenGui.Parent do
			updateRollButton()
			updateLuckStatus()
			task.wait(0.25)
		end
	end)
end

return EconomyController
