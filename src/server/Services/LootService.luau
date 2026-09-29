--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local FactoryService = require(script.Parent.FactoryService)
local EffectService = require(script.Parent.EffectService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local LootService = {}
local started = false
local active: { [Player]: { BasePart } } = {}
local offsets = {
	Vector3.new(4, 1.5, 9),
	Vector3.new(14, 1.5, -9),
	Vector3.new(26, 1.5, 9),
}
local spawnIndex: { [Player]: number } = {}
local MAX_ACTIVE = 3
local SPAWN_INTERVAL = 12
local COIN_REWARD = 5

function LootService.claim(player: Player, part: BasePart): boolean
	local factory = FactoryService.getState(player)
	if not factory or player:GetAttribute("FactoryDataReady") ~= true or part.Name ~= "CoinDrop" or part.Parent ~= factory.plot or part:GetAttribute("OwnerUserId") ~= player.UserId or part:GetAttribute("Claimed") then
		return false
	end
	part:SetAttribute("Claimed", true)
	if not factory.simulation:grantCoins(COIN_REWARD) then
		part:SetAttribute("Claimed", false)
		return false
	end
	part:Destroy()
	AnalyticsService.record(player, "LootCollected")
	EffectService.fire(player, "LootClaimed", { Coins = COIN_REWARD })
	return true
end

local function spawnLoot(player: Player)
	local factory = FactoryService.getState(player)
	if not factory or player:GetAttribute("FactoryDataReady") ~= true or not player.Parent then
		return
	end
	local pieces = active[player]
	if not pieces then
		pieces = {}
		active[player] = pieces
	end
	for index = #pieces, 1, -1 do
		if not pieces[index].Parent then
			table.remove(pieces, index)
		end
	end
	if #pieces >= MAX_ACTIVE then
		return
	end
	local index = (spawnIndex[player] or 0) % #offsets + 1
	spawnIndex[player] = index
	local part = Instance.new("Part")
	part.Name = "CoinDrop"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 218, 76)
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Position = factory.origin + offsets[index]
	part:SetAttribute("OwnerUserId", player.UserId)
	part.Parent = factory.plot
	TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(1.3, 1.3, 1.3),
		Transparency = 0,
	}):Play()
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect +5 Coins"
	prompt.ObjectText = "Factory drop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = part
	table.insert(pieces, part)
	prompt.Triggered:Connect(function(collector: Player)
		LootService.claim(collector, part)
	end)
	EffectService.fire(player, "LootSpawned")
end

function LootService.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		spawnIndex[player] = nil
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			for _, player in Players:GetPlayers() do
				spawnLoot(player)
			end
			task.wait(SPAWN_INTERVAL)
		end
	end)
end

return LootService
