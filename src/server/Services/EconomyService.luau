--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local BoosterConfig = require(Shared:WaitForChild("BoosterConfig"))
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

local function refreshLuck(player: Player, profile: any, notifyExpired: boolean): number
	local now = workspace:GetServerTimeNow()
	local wasActive = profile.LuckMultiplier > 1 and profile.LuckExpiresAt > 0
	if wasActive and profile.LuckExpiresAt <= now then
		profile.LuckMultiplier = 1
		profile.LuckExpiresAt = 0
		if notifyExpired then EffectService.fire(player, "InventoryChanged") end
	end
	if player:GetAttribute("FactoryLuckMultiplier") ~= profile.LuckMultiplier then
		player:SetAttribute("FactoryLuckMultiplier", profile.LuckMultiplier)
	end
	if player:GetAttribute("FactoryLuckExpiresAt") ~= profile.LuckExpiresAt then
		player:SetAttribute("FactoryLuckExpiresAt", profile.LuckExpiresAt)
	end
	return profile.LuckMultiplier
end

local function refreshSaleValueBoost(player: Player, profile: any): { [string]: number }
	local now = workspace:GetServerTimeNow()
	if profile.SaleValueExpiresAt <= now then
		profile.SaleValueAdditiveBonus = 0
		profile.SaleValueMultiplier = 1
		profile.SaleValueExpiresAt = 0
	end
	if player:GetAttribute("FactorySaleValueAdditiveBonus") ~= profile.SaleValueAdditiveBonus then
		player:SetAttribute("FactorySaleValueAdditiveBonus", profile.SaleValueAdditiveBonus)
	end
	if player:GetAttribute("FactorySaleValueMultiplier") ~= profile.SaleValueMultiplier then
		player:SetAttribute("FactorySaleValueMultiplier", profile.SaleValueMultiplier)
	end
	if player:GetAttribute("FactorySaleValueExpiresAt") ~= profile.SaleValueExpiresAt then
		player:SetAttribute("FactorySaleValueExpiresAt", profile.SaleValueExpiresAt)
	end
	return {
		AdditiveBonus = profile.SaleValueAdditiveBonus,
		Multiplier = profile.SaleValueMultiplier,
		ExpiresAt = profile.SaleValueExpiresAt,
	}
end

local function getProfile(player: Player): any
	local profile = profiles[player]
	if not profile then
		profile = {
			RollCount = 0,
			NextRollAt = 0,
			LuckMultiplier = 1,
			LuckExpiresAt = 0,
			SaleValueAdditiveBonus = 0,
			SaleValueMultiplier = 1,
			SaleValueExpiresAt = 0,
		}
		profiles[player] = profile
		player:SetAttribute("FactoryLuckMultiplier", 1)
		player:SetAttribute("FactoryLuckExpiresAt", 0)
		player:SetAttribute("FactorySaleValueAdditiveBonus", 0)
		player:SetAttribute("FactorySaleValueMultiplier", 1)
		player:SetAttribute("FactorySaleValueExpiresAt", 0)
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
	local luckMultiplier = refreshLuck(player, profile, false)
	local saleValueBoost = refreshSaleValueBoost(player, profile)
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
		DataReady = dataIsReady(player),
		DataError = player:GetAttribute("FactoryDataError"),
		CapacityCost = capacityCost,
		LastRoll = player:GetAttribute("FactoryLastRoll"),
		LastRarity = player:GetAttribute("FactoryLastRarity"),
		LastRollLuckMultiplier = player:GetAttribute("FactoryLastRollLuckMultiplier") or 1,
		LuckMultiplier = luckMultiplier,
		LuckExpiresAt = profile.LuckExpiresAt,
		SaleValueAdditiveBonus = saleValueBoost.AdditiveBonus,
		SaleValueMultiplier = saleValueBoost.Multiplier,
		SaleValueExpiresAt = saleValueBoost.ExpiresAt,
	}
end

local function chooseMachine(luckMultiplier: number): (any?, { any })
	local baseRollPool = MachineDefinitions.getRollPool()
	local rollPool = EconomyRules.getLuckAdjustedRollPool(baseRollPool, luckMultiplier)
	local totalChance = EconomyRules.getRollPoolTotalChance(rollPool)
	if totalChance <= 0 then return nil, rollPool end
	local machineId = EconomyRules.pickMachineId(rollPool, random:NextNumber() * totalChance)
	return machineId and MachineDefinitions.get(machineId) or nil, rollPool
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
	if not state then return { Success = false, Reason = "Factory is not ready" } end
	if not dataIsReady(player) then return response(player, false, "Factory data is loading") end
	if isRateLimited(player) then return response(player, false, "Too many requests") end
	local profile = getProfile(player)
	local now = os.clock()
	local canRoll, reason = EconomyRules.canRoll(profile.NextRollAt, now, inventoryCount(state.inventory))
	if not canRoll then return response(player, false, reason) end
	local luckMultiplier = refreshLuck(player, profile, false)
	local definition, rollPool = chooseMachine(luckMultiplier)
	if not definition then return response(player, false, "No rollable machines are configured") end
	local rarity = EconomyRules.getMachineRarity(definition.Id, rollPool) or definition.Rarity
	state.inventory[definition.Id] = (state.inventory[definition.Id] or 0) + 1
	profile.RollCount += 1
	profile.NextRollAt = now + EconomyConfig.RollCooldownSeconds
	player:SetAttribute("FactoryLastRoll", definition.Id)
	player:SetAttribute("FactoryLastRarity", rarity)
	player:SetAttribute("FactoryLastRollLuckMultiplier", luckMultiplier)
	AnalyticsService.record(player, "MachineRolled")
	if (AnalyticsService.snapshot(player).MachineRolled or 0) == 1 then AnalyticsService.record(player, "FirstRoll") end
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

function EconomyService.grantLuckBoost(player: Player, multiplier: number, durationSeconds: number): boolean
	if not dataIsReady(player) or type(multiplier) ~= "number" or multiplier ~= multiplier
		or type(durationSeconds) ~= "number" or durationSeconds ~= durationSeconds
		or multiplier < 1 or multiplier > EconomyConfig.MaxLuckMultiplier
		or durationSeconds < 1 or durationSeconds > BoosterConfig.MaxLuckDurationSeconds then
		return false
	end
	local profile = getProfile(player)
	local currentMultiplier = refreshLuck(player, profile, false)
	local now = workspace:GetServerTimeNow()
	profile.LuckMultiplier = math.max(currentMultiplier, multiplier)
	profile.LuckExpiresAt = math.min(math.max(profile.LuckExpiresAt, now + durationSeconds), now + BoosterConfig.MaxLuckDurationSeconds)
	refreshLuck(player, profile, false)
	return true
end

function EconomyService.grantSaleValueBoost(player: Player, additiveBonus: number, multiplier: number, durationSeconds: number): boolean
	if not dataIsReady(player)
		or type(additiveBonus) ~= "number" or additiveBonus ~= additiveBonus or additiveBonus < 0 or additiveBonus == math.huge
		or type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 or multiplier > EconomyConfig.MaxSaleValueMultiplier
		or type(durationSeconds) ~= "number" or durationSeconds ~= durationSeconds or durationSeconds < 1
			or durationSeconds > BoosterConfig.MaxSaleValueDurationSeconds then
		return false
	end

	local profile = getProfile(player)
	local current = refreshSaleValueBoost(player, profile)
	local now = workspace:GetServerTimeNow()
	profile.SaleValueAdditiveBonus = math.min(current.AdditiveBonus + additiveBonus, FactoryConfig.MaxItemValue)
	profile.SaleValueMultiplier = math.min(current.Multiplier * multiplier, EconomyConfig.MaxSaleValueMultiplier)
	profile.SaleValueExpiresAt = math.min(
		math.max(profile.SaleValueExpiresAt, now + durationSeconds),
		now + BoosterConfig.MaxSaleValueDurationSeconds
	)
	refreshSaleValueBoost(player, profile)
	return true
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
	task.spawn(function()
		while true do
			for player, profile in pairs(profiles) do
				refreshLuck(player, profile, true)
				refreshSaleValueBoost(player, profile)
			end
			task.wait(1)
		end
	end)
end

return EconomyService
