--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoosterConfig = require(Shared:WaitForChild("BoosterConfig"))
local BoosterRules = require(Shared:WaitForChild("BoosterRules"))
local FactoryService = require(script.Parent.FactoryService)
local EconomyService = require(script.Parent.EconomyService)
local EffectService = require(script.Parent.EffectService)

local BoosterService = {}
local started = false
local lastUseAt: { [Player]: number } = {}

function BoosterService.collect(player: Player, boosterId: any): boolean
	local factory = FactoryService.getState(player)
	local definition = BoosterRules.get(boosterId)
	if not factory or player:GetAttribute("FactoryDataReady") ~= true or not definition then return false end
	local stored = factory.boosterInventory[boosterId] or 0
	if stored >= BoosterConfig.MaxStoredPerType then return false end
	factory.boosterInventory[boosterId] = stored + 1
	EffectService.fire(player, "InventoryChanged")
	return true
end

local function useBooster(player: Player, boosterId: any): { [string]: any }
	local factory = FactoryService.getState(player)
	local definition = BoosterRules.get(boosterId)
	if not factory or player:GetAttribute("FactoryDataReady") ~= true then
		return { Success = false, Reason = "Factory data is not ready" }
	end
	if not definition or (factory.boosterInventory[boosterId] or 0) < 1 then
		return { Success = false, Reason = "Booster is not in your inventory" }
	end
	local now = os.clock()
	if now - (lastUseAt[player] or -math.huge) < 0.2 then
		return { Success = false, Reason = "Wait before using another booster" }
	end
	lastUseAt[player] = now

	local effect = definition.Effect
	local applied = false
	local payload: { [string]: any } = { BoosterId = boosterId, DisplayName = definition.DisplayName }
	if effect.Kind == "Coins" then
		applied = factory.simulation:grantCoins(effect.Amount)
		payload.Coins = effect.Amount
	elseif effect.Kind == "Luck" then
		applied = EconomyService.grantLuckBoost(player, effect.Multiplier, effect.DurationSeconds)
		payload.Multiplier = effect.Multiplier
		payload.DurationSeconds = effect.DurationSeconds
	end
	if not applied then return { Success = false, Reason = "Booster could not be used right now" } end
	local remaining = factory.boosterInventory[boosterId] - 1
	factory.boosterInventory[boosterId] = if remaining > 0 then remaining else nil
	EffectService.fire(player, "InventoryChanged")
	EffectService.fire(player, "BoosterUsed", payload)
	return { Success = true, BoosterInventory = BoosterRules.sanitizeInventory(factory.boosterInventory) }
end

function BoosterService.start()
	if started then return end
	started = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Factory")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "UseBooster"
	remote.OnServerInvoke = useBooster
	remote.Parent = remotes
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastUseAt[player] = nil
	end)
end

return BoosterService
