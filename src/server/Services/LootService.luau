--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoosterConfig = require(Shared:WaitForChild("BoosterConfig"))
local BoosterRules = require(Shared:WaitForChild("BoosterRules"))
local FactoryService = require(script.Parent.FactoryService)
local EconomyService = require(script.Parent.EconomyService)
local EffectService = require(script.Parent.EffectService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local LootService = {}
local started = false
local activeDrops: { [Player]: { BasePart } } = {}
local random = Random.new()

local function getWorldFolder(): Folder
	local existing = workspace:FindFirstChild(BoosterConfig.WorldFolderName)
	if existing and existing:IsA("Folder") then return existing end
	local folder = Instance.new("Folder")
	folder.Name = BoosterConfig.WorldFolderName
	folder.Parent = workspace
	return folder
end

local function getActiveDropCount(player: Player): number
	local drops = activeDrops[player]
	if not drops then return 0 end
	for index = #drops, 1, -1 do
		if not drops[index].Parent then table.remove(drops, index) end
	end
	return #drops
end

local function grantBooster(player: Player, factory: any, booster: any): (boolean, { [string]: any }?)
	local effect = booster.Effect
	local payload: { [string]: any } = { BoosterId = booster.Id, DisplayName = booster.DisplayName }
	if effect.Kind == "Coins" then
		if not factory.simulation:grantCoins(effect.Amount) then return false, nil end
		payload.Coins = effect.Amount
	elseif effect.Kind == "Luck" then
		if not EconomyService.grantLuckBoost(player, effect.Multiplier, effect.DurationSeconds) then return false, nil end
		payload.Multiplier = effect.Multiplier
		payload.DurationSeconds = effect.DurationSeconds
	else
		return false, nil
	end
	return true, payload
end

function LootService.claim(player: Player, part: BasePart): boolean
	local factory = FactoryService.getState(player)
	if not factory or player:GetAttribute("FactoryDataReady") ~= true or not part:IsA("BasePart")
		or part.Parent ~= getWorldFolder() or part:GetAttribute("Claimed") == true then
		return false
	end
	local booster = BoosterRules.get(part:GetAttribute("BoosterId"))
	if not booster then return false end
	part:SetAttribute("Claimed", true)
	local granted, payload = grantBooster(player, factory, booster)
	if not granted or not payload then
		part:SetAttribute("Claimed", false)
		return false
	end
	part:Destroy()
	AnalyticsService.record(player, "LootCollected")
	EffectService.fire(player, "InventoryChanged")
	EffectService.fire(player, "LootClaimed", payload)
	return true
end

local function connectTouchPickup(part: BasePart)
	part.Touched:Connect(function(hit: BasePart)
		if part:GetAttribute("Claimed") == true then return end
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character or not character:FindFirstChildOfClass("Humanoid") then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player then LootService.claim(player, part) end
	end)
end

local function addDisplay(part: BasePart, booster: any)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BoosterLabel"
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 70
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, 1.05, 0)
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(28, 24, 21)
	label.BackgroundTransparency = 0.1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = booster.DisplayName
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 12
	label.TextWrapped = false
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function spawnLoot(player: Player)
	local factory = FactoryService.getState(player)
	if not factory or player:GetAttribute("FactoryDataReady") ~= true or not player.Parent then return end
	if getActiveDropCount(player) >= BoosterConfig.MaxActiveDropsPerFactory then return end
	local folder = getWorldFolder()
	if #folder:GetChildren() >= BoosterConfig.MaxActiveDropsWorldwide then return end
	local totalWeight = BoosterRules.getTotalSpawnWeight()
	local boosterId = BoosterRules.pickBoosterId(random:NextNumber() * totalWeight)
	local booster = BoosterRules.get(boosterId)
	if not booster then return end
	local bounds = BoosterConfig.SpawnBounds
	local position = factory.origin + Vector3.new(random:NextNumber(bounds.MinX, bounds.MaxX), bounds.Height, random:NextNumber(bounds.MinZ, bounds.MaxZ))
	local part = Instance.new("Part")
	part.Name = "WorldBoosterDrop"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(booster.Color[1], booster.Color[2], booster.Color[3])
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	part.Position = position
	part:SetAttribute("BoosterId", booster.Id)
	part:SetAttribute("SourcePlotUserId", player.UserId)
	part:SetAttribute("Claimed", false)
	part.Parent = folder
	addDisplay(part, booster)
	connectTouchPickup(part)
	local drops = activeDrops[player]
	if not drops then drops = {}; activeDrops[player] = drops end
	table.insert(drops, part)
	TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(1.3, 1.3, 1.3), Transparency = 0 }):Play()
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = part
	task.delay(BoosterConfig.DespawnAfterSeconds, function()
		if part.Parent then part:Destroy() end
	end)
end

local function removePlayerDrops(player: Player)
	local folder = workspace:FindFirstChild(BoosterConfig.WorldFolderName)
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			if part:GetAttribute("SourcePlotUserId") == player.UserId then part:Destroy() end
		end
	end
	activeDrops[player] = nil
end

function LootService.start()
	if started then return end
	started = true
	getWorldFolder()
	Players.PlayerRemoving:Connect(removePlayerDrops)
	task.spawn(function()
		task.wait(5)
		while true do
			for _, player in Players:GetPlayers() do spawnLoot(player) end
			task.wait(BoosterConfig.SpawnIntervalSeconds)
		end
	end)
end

return LootService
