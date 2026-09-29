--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local BoosterConfig = require(Shared:WaitForChild("BoosterConfig"))
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))

-- A small event registry keeps presentation separate from gameplay authority.
-- New moments can register a handler without changing the economy or factory services.
local EffectsController = {}
local handlers: { [string]: ({ [string]: any }) -> () } = {}
local started = false
local sequence = 0
local toastSequence = 0

local rarityColors: { [string]: Color3 } = {}
for _, band in ipairs(EconomyConfig.RarityOddsBands) do
	local color = band.Color
	rarityColors[band.Name] = Color3.fromRGB(color[1], color[2], color[3])
end
local firstRarityBand = EconomyConfig.RarityOddsBands[1]
local defaultRarityColor = Color3.new(1, 1, 1)
if firstRarityBand then
	defaultRarityColor = rarityColors[firstRarityBand.Name] or defaultRarityColor
end

local function getRarityColor(rarity: string): Color3
	return rarityColors[rarity] or defaultRarityColor
end

local function getBoosterColor(boosterId: string?): Color3
	for _, booster in ipairs(BoosterConfig.Definitions) do
		if booster.Id == boosterId then
			local color = booster.Color
			return Color3.fromRGB(color[1], color[2], color[3])
		end
	end
	return getRarityColor("Legendary")
end

function EffectsController.register(eventName: string, handler: ({ [string]: any }) -> ())
	handlers[eventName] = handler
end

function EffectsController.play(eventName: string, payload: { [string]: any }?)
	local handler = handlers[eventName]
	if handler then
		handler(payload or {})
	end
end

function EffectsController.start()
	if started then
		return
	end
	started = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Factory"):WaitForChild("PresentationEvent") :: RemoteEvent
	local gui = Instance.new("ScreenGui")
	gui.Name = "FactoryEffects"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "CutsceneOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = gui

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.AnchorPoint = Vector2.new(0.5, 1)
	heading.Position = UDim2.fromScale(0.5, 0.38)
	heading.Size = UDim2.new(0.8, 0, 0, 40)
	heading.BackgroundTransparency = 1
	heading.TextColor3 = Color3.new(1, 1, 1)
	heading.Font = Enum.Font.GothamBlack
	heading.TextScaled = true
	heading.Parent = overlay

	local card = Instance.new("TextLabel")
	card.Name = "RevealCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0.9, 0, 0, 96)
	card.BackgroundColor3 = Color3.fromRGB(34, 30, 42)
	card.TextColor3 = Color3.new(1, 1, 1)
	card.Font = Enum.Font.GothamBlack
	card.TextScaled = true
	card.TextWrapped = false
	local cardTextLimit = Instance.new("UITextSizeConstraint")
	cardTextLimit.MinTextSize = 14
	cardTextLimit.MaxTextSize = 20
	cardTextLimit.Parent = card
	card.Parent = overlay
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(600, 96)
	sizeLimit.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = getRarityColor("Common")
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local pulse: Tween? = nil

	local toast = Instance.new("TextLabel")
	toast.Name = "EventToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 24)
	toast.Size = UDim2.new(0.7, 0, 0, 48)
	toast.BackgroundColor3 = Color3.fromRGB(28, 24, 32)
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Font = Enum.Font.GothamBold
	toast.TextScaled = true
	toast.TextWrapped = true
	toast.Parent = gui
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(420, 48)
	toastLimit.Parent = toast
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 12)
	toastCorner.Parent = toast

	local function showToast(message: string, color: Color3)
		toastSequence += 1
		local token = toastSequence
		toast.Text = message
		toast.TextColor3 = color
		TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.12, TextTransparency = 0 }):Play()
		task.delay(2.4, function()
			if token == toastSequence then
				TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			end
		end)
	end

	EffectsController.register("RollPending", function()
		sequence += 1
		if pulse then
			pulse:Cancel()
		end
		overlay.Visible = true
		heading.Text = "ROLLING A MACHINE"
		card.Text = "? ? ?"
		stroke.Color = getRarityColor("Common")
		scale.Scale = 1
		pulse = TweenService:Create(scale, TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.07 })
		pulse:Play()
	end)

	EffectsController.register("UltraRareRollCutscene", function(payload)
		sequence += 1
		local token = sequence
		if pulse then
			pulse:Cancel()
		end
		overlay.Visible = true
		overlay.BackgroundTransparency = 0.12
		heading.Text = "ULTRA RARE MACHINE!"
		local rarity = payload.Rarity or "Legendary"
		local rarityColor = getRarityColor(rarity)
		stroke.Color = rarityColor
		card.Text = string.format("%s · %s", payload.MachineName or "New machine", payload.Odds or "1/?")
		scale.Scale = 0.72
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(EconomyConfig.UltraRareCutscene.DurationSeconds, function()
			if token == sequence then
				overlay.Visible = false
				overlay.BackgroundTransparency = 0.35
				showToast("Ultra rare roll!", rarityColor)
			end
		end)
	end)

	EffectsController.register("MachineRolled", function(payload)
		sequence += 1
		local token = sequence
		if pulse then
			pulse:Cancel()
		end
		overlay.Visible = true
		heading.Text = "ROLLING A MACHINE"
		local basePool = MachineDefinitions.getRollPool()
		local luckMultiplier = payload.LuckMultiplier or 1
		local pool = EconomyRules.getLuckAdjustedRollPool(basePool, luckMultiplier)
		local definition = MachineDefinitions.get(payload.MachineId or "")
		local rarity = payload.Rarity or (definition and EconomyRules.getMachineRarity(definition.Id, pool)) or "Common"
		local odds = if definition then EconomyRules.getMachineOddsLabel(definition.Id, pool) else nil
		task.spawn(function()
			for index = 1, 16 do
				if token ~= sequence then
					return
				end
				local sample = pool[(index * 7) % #pool + 1]
				local sampleOdds = EconomyRules.getMachineOddsLabel(sample.Id, pool) or "1/?"
				card.Text = string.format("%s · %s", sample.DisplayName, sampleOdds)
				local sampleRarity = EconomyRules.getMachineRarity(sample.Id, pool) or sample.Rarity
				stroke.Color = getRarityColor(sampleRarity)
				card.Rotation = if index % 2 == 0 then 2 else -2
				task.wait(0.045 + index * 0.005)
			end
			if token ~= sequence then
				return
			end
			card.Rotation = 0
			card.Text = if definition and odds then string.format("%s · %s", definition.DisplayName, odds) else "New machine"
			stroke.Color = getRarityColor(rarity)
			heading.Text = string.upper(rarity) .. " MACHINE!"
			scale.Scale = 1.25
			TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			local oddsDenominator = if definition then EconomyRules.getMachineOddsDenominator(definition.Id, pool) else nil
			if EconomyRules.shouldPlayUltraRareCutscene(oddsDenominator) then
				task.wait(0.55)
				if token == sequence then
					EffectsController.play("UltraRareRollCutscene", {
						MachineName = definition.DisplayName,
						Rarity = rarity,
						Odds = odds or "1/?",
					})
				end
				return
			end
			task.wait(1.2)
			if token == sequence then
				overlay.Visible = false
			end
		end)
	end)

	EffectsController.register("RollRejected", function(payload)
		sequence += 1
		if pulse then
			pulse:Cancel()
		end
		overlay.Visible = false
		showToast(payload.Reason or "Roll unavailable", Color3.fromRGB(255, 150, 120))
	end)
	EffectsController.register("FirstItemSpawned", function()
		showToast("Your dropper made its first item!", getRarityColor("Rare"))
	end)
	EffectsController.register("FirstItemSold", function()
		showToast("First sale! The seller earned Coins.", getRarityColor("Uncommon"))
	end)
	EffectsController.register("LootSpawned", function(payload)
		showToast("A booster appeared nearby", getBoosterColor(payload.BoosterId))
	end)
	EffectsController.register("LootClaimed", function(payload)
		local boosterColor = getBoosterColor(payload.BoosterId)
		if payload.BoosterId == "Luck" then
			showToast(string.format("Luck x%.1f · %ds", payload.Multiplier or 2, payload.DurationSeconds or 0), boosterColor)
		else
			showToast(string.format("Found +%d Coins!", payload.Coins or 0), boosterColor)
		end
	end)

	remote.OnClientEvent:Connect(function(eventName: string, payload: { [string]: any })
		EffectsController.play(eventName, payload)
	end)
end

return EffectsController
