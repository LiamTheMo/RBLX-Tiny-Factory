--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local EconomyRules = require(Shared:WaitForChild("EconomyRules"))
local FactoryConfig = require(Shared:WaitForChild("FactoryConfig"))
local MachineDefinitions = require(Shared:WaitForChild("MachineDefinitions"))
local FactoryService = require(script.Parent.FactoryService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local EffectService = require(script.Parent.EffectService)

local EconomyService = {}
local profiles = {}
local lastRequestAt = {}
local started = false
local random = Random.new()

local function copyInventory(inventory: { [string]: number }): { [string]: number }
	local result = {}
	for machineId, quantity in pairs(inventory) do
		result[machineId] = quantity
	end
	return result
end

local function getState(player: Player): any?
	return FactoryService.getState(player)
end

local function dataIsReady(player: Player): boolean
	return player:GetAttribute("FactoryDataReady") == true
end

local function getProfile(player: Player): any
	local profile = profiles[player]
	if not profile then
		profile = { RollCount = 0, NextRollAt = 0 }
		profiles[player] = profile
	end
	return profile
end

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local previous = lastRequestAt[player] or 0
	if now - previous < 0.1 then
		return true
	end
	lastRequestAt[player] = now
	return false
end

local function getWallet(state: any): number
	return state.simulation:getSnapshot().Coins
end

local function inventoryCount(inventory: { [string]: number }): number
	local count = 0
	for _, quantity in pairs(inventory) do
		count += quantity
	end
	return count
end

local function getClientState(player: Player): { [string]: any }
	local state = getState(player)
	if not state then
		return { Success = false, Reason = "Factory is not ready" }
	end
	local profile = getProfile(player)
	local rollCost = EconomyRules.getRollCost(profile.RollCount)
	local capacityCost = EconomyRules.getCapacityCost(state.capacity)
	return {
		Success = true,
		Coins = getWallet(state),
		Inventory = copyInventory(state.inventory),
		InventoryCount = inventoryCount(state.inventory),
		MaxInventoryMachines = EconomyConfig.MaxInventoryMachines,
		Capacity = state.capacity,
		MaxCapacity = FactoryConfig.MaxFactoryCapacity,
		RollCount = profile.RollCount,
		RollCost = rollCost,
		RollCooldownSeconds = EconomyConfig.RollCooldownSeconds,
		RollCooldownRemaining = EconomyRules.getRollCooldownRemaining(profile.NextRollAt, os.clock()),
		RollChances = EconomyRules.getMachineRollChances(EconomyConfig.RarityWeights, MachineDefinitions.getRollPool()),
		LastRollChance = profile.LastRollChance,
		DataReady = dataIsReady(player),
		DataError = player:GetAttribute("FactoryDataError"),
		CapacityCost = capacityCost,
		LastRoll = player:GetAttribute("FactoryLastRoll"),
		LastRarity = player:GetAttribute("FactoryLastRarity"),
	}
end

local function chooseRarity(): string?
	local totalWeight = 0
	for _, weight in pairs(EconomyConfig.RarityWeights) do
		totalWeight += weight
	end
	return EconomyRules.weightedPick(EconomyConfig.RarityWeights, random:NextNumber(0, totalWeight))
end

local function chooseMachine(rarity: string?): any?
	local candidates = MachineDefinitions.getRollPool(rarity)
	if #candidates == 0 then
		return nil
	end
	local weights = {}
	for _, definition in ipairs(candidates) do weights[definition.Id] = definition.RollWeight or 0 end
	local totalWeight = 0
	for _, weight in pairs(weights) do totalWeight += weight end
	local chosenId = EconomyRules.weightedPick(weights, random:NextNumber(0, totalWeight))
	return if chosenId then MachineDefinitions.get(chosenId) else nil
end

local function response(player: Player, success: boolean, reason: string?): { [string]: any }
	local state = getState(player)
	local result = getClientState(player)
	result.Success = success
	result.Reason = reason
	if state then
		result.Coins = getWallet(state)
		result.Inventory = copyInventory(state.inventory)
	end
	return result
end

local function rollMachine(player: Player)
	local state = getState(player)
	if not state then
		return { Success = false, Reason = "Factory is not ready" }
	end
	if not dataIsReady(player) then
		return response(player, false, "Factory data is loading")
	end
	if isRateLimited(player) then
		return response(player, false, "Too many requests")
	end
	local profile = getProfile(player)
	local now = os.clock()
	local canRoll, reason = EconomyRules.canRoll(profile.NextRollAt, now, inventoryCount(state.inventory))
	if not canRoll then
		return response(player, false, reason)
	end

	local rarity = chooseRarity()
	local definition = chooseMachine(rarity)
	if not definition then
		return response(player, false, "No rollable machines are configured")
	end
	state.inventory[definition.Id] = (state.inventory[definition.Id] or 0) + 1
	profile.RollCount += 1
	profile.NextRollAt = now + EconomyConfig.RollCooldownSeconds
	profile.LastRollChance = EconomyRules.getMachineRollChances(EconomyConfig.RarityWeights, MachineDefinitions.getRollPool())[definition.Id] or 0
	player:SetAttribute("FactoryLastRoll", definition.Id)
	player:SetAttribute("FactoryLastRarity", definition.Rarity)
	AnalyticsService.record(player, "MachineRolled")
	EffectService.fire(player, "InventoryChanged")
	return response(player, true)
end

local function sellMachine(player: Player, machineId: any, quantity: any)
	local state = getState(player)
	if not state then
		return { Success = false, Reason = "Factory is not ready" }
	end
	if not dataIsReady(player) then
		return response(player, false, "Factory data is loading")
	end
	if isRateLimited(player) then
		return response(player, false, "Too many requests")
	end
	if type(machineId) ~= "string" or type(quantity) ~= "number" or quantity % 1 ~= 0 or quantity <= 0 or quantity > 100 then
		return response(player, false, "Invalid resale request")
	end
	local definition = MachineDefinitions.get(machineId)
	local owned = state.inventory[machineId] or 0
	if not definition or not definition.Rollable or owned < quantity then
		return response(player, false, "Machine is not available for resale")
	end

	local refundEach = EconomyRules.getResaleValue(definition.Rarity)
	state.inventory[machineId] -= quantity
	local refunded = refundEach * quantity
	if not state.simulation:grantCoins(refunded) then
		state.inventory[machineId] += quantity
		return response(player, false, "Unable to credit resale")
	end
	AnalyticsService.record(player, "MachineRecycled", quantity)
	EffectService.fire(player, "InventoryChanged")
	return response(player, true)
end

local function buyCapacity(player: Player)
	local state = getState(player)
	if not state then
		return { Success = false, Reason = "Factory is not ready" }
	end
	if not dataIsReady(player) then
		return response(player, false, "Factory data is loading")
	end
	if isRateLimited(player) then
		return response(player, false, "Too many requests")
	end
	local cost, costError = EconomyRules.getCapacityCost(state.capacity)
	if not cost then
		return response(player, false, costError)
	end
	if not state.simulation:tryDebitCoins(cost) then
		return response(player, false, "Not enough Coins")
	end
	local changed, changeError = FactoryService.setCapacity(player, state.capacity + 1)
	if not changed then
		state.simulation:grantCoins(cost)
		return response(player, false, changeError)
	end
	AnalyticsService.record(player, "CapacityPurchased")
	EffectService.fire(player, "InventoryChanged")
	return response(player, true)
end

function EconomyService.getPersistentState(player: Player): { [string]: any }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return { RollCount = profile.RollCount }
end

function EconomyService.applyPersistentState(player: Player, data: { [string]: any }): (boolean, string?)
	local profile = getProfile(player)
	if type(data.RollCount) ~= "number" or data.RollCount % 1 ~= 0 or data.RollCount < 0 then
		return false, "Invalid economy data"
	end
	profile.RollCount = math.min(data.RollCount, 100_000)
	return true
end

local function createRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local factoryRemotes = remotes:WaitForChild("Factory")
	local function remoteFunction(name: string): RemoteFunction
		local remote = factoryRemotes:FindFirstChild(name) :: RemoteFunction?
		if not remote then
			remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = factoryRemotes
		end
		return remote
	end
	remoteFunction("GetEconomyState").OnServerInvoke = getClientState
	remoteFunction("RollMachine").OnServerInvoke = rollMachine
	remoteFunction("SellMachine").OnServerInvoke = sellMachine
	remoteFunction("BuyCapacity").OnServerInvoke = buyCapacity
end

function EconomyService.start()
	if started then
		return
	end
	started = true
	createRemotes()
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
		lastRequestAt[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		getProfile(player)
	end
end

return EconomyService
