--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local FactoryService = require(script.Parent.FactoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local EffectService = require(script.Parent.EffectService)

local DataService = {}
local store: any = nil
local sessionIds: { [Player]: string } = {}
local loadedPlayers: { [Player]: boolean } = {}
local started = false
local lockRefreshAccumulator = 0

local SESSION_LOCK_SECONDS = 300

local function sessionIdFor(player: Player): string
	local jobId = game.JobId
	if jobId == "" then
		jobId = HttpService:GenerateGUID(false)
	end
	return `{jobId}:{player.UserId}`
end

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function unpackRecord(value: any): ({ [string]: any }, any, number?)
	if type(value) ~= "table" then
		return {}, nil, nil
	end
	local data = if type(value.Data) == "table" then value.Data else value
	local owner = value._SessionId
	local lastSeen = value._LastSeen
	return data, owner, if type(lastSeen) == "number" then lastSeen else nil
end

local function setLoadStatus(player: Player, loaded: boolean, locked: boolean, reason: string?, allowUnsavedPrototype: boolean?)
	player:SetAttribute("FactoryDataLoaded", loaded)
	player:SetAttribute("FactoryDataLocked", locked)
	player:SetAttribute("FactoryDataReady", loaded or allowUnsavedPrototype == true)
	if reason then
		player:SetAttribute("FactoryDataError", reason)
	else
		player:SetAttribute("FactoryDataError", nil)
	end
	EffectService.fire(player, "InventoryChanged")
end

local function loadPlayer(player: Player)
	while player.Parent == Players and not FactoryService.getState(player) do
		task.wait()
	end
	if player.Parent ~= Players then
		return
	end
	if not store then
		-- Only a local, unpublished Rojo build may play without cloud saving.
		-- A published place with an unavailable store must not accept changes.
		if game.PlaceId == 0 then
			setLoadStatus(player, false, false, "Saving requires a published place", true)
		else
			setLoadStatus(player, false, false, "Data store unavailable")
		end
		return
	end
	if sessionIds[player] then
		return
	end
	local sessionId = sessionIdFor(player)
	sessionIds[player] = sessionId
	setLoadStatus(player, false, false, nil)

	local lockedByAnotherSession = false
	local now = os.time()
	local success, storedValue = pcall(function()
		return store:UpdateAsync(keyFor(player), function(oldValue)
			local oldData, oldOwner, oldLastSeen = unpackRecord(oldValue)
			if oldOwner and oldOwner ~= sessionId and oldLastSeen and now - oldLastSeen < SESSION_LOCK_SECONDS then
				lockedByAnotherSession = true
				return nil
			end
			return {
				Data = SaveSchema.sanitize(oldData),
				_SessionId = sessionId,
				_LastSeen = now,
			}
		end)
	end)

	if not success then
		sessionIds[player] = nil
		setLoadStatus(player, false, false, "Data store unavailable")
		AnalyticsService.record(player, "DataLoadFailure")
		warn(`Tiny Factory data load failed for {player.UserId}: {storedValue}`)
		return
	end
	if lockedByAnotherSession or storedValue == nil then
		sessionIds[player] = nil
		setLoadStatus(player, false, true, "Active session already owns this data")
		return
	end

	local rawData = unpackRecord(storedValue)
	local safeData = SaveSchema.sanitize(rawData)
	local factoryApplied, factoryError = FactoryService.applyPersistentState(player, safeData)
	local economyApplied, economyError = EconomyService.applyPersistentState(player, safeData)
	if not factoryApplied or not economyApplied then
		sessionIds[player] = nil
		setLoadStatus(player, false, false, factoryError or economyError or "Invalid saved data")
		AnalyticsService.record(player, "DataLoadFailure")
		warn(`Tiny Factory data apply failed for {player.UserId}: {factoryError or economyError}`)
		return
	end
	AnalyticsService.restore(player, safeData.Analytics)
	loadedPlayers[player] = true
	setLoadStatus(player, true, false, nil)
end

local function savePlayer(player: Player, releaseLock: boolean?)
	local sessionId = sessionIds[player]
	if not sessionId or not loadedPlayers[player] then
		return
	end
	local factoryData = FactoryService.getPersistentState(player)
	local economyData = EconomyService.getPersistentState(player)
	if not factoryData or not economyData then
		return
	end

	local safeData = SaveSchema.sanitize({
		Coins = factoryData.Coins,
		Layout = factoryData.Layout,
		Inventory = factoryData.Inventory,
		BoosterInventory = factoryData.BoosterInventory,
		Capacity = factoryData.Capacity,
		RollCount = economyData.RollCount,
		Statistics = factoryData.Statistics,
		Analytics = AnalyticsService.snapshot(player),
	})
	local conflict = false
	local now = os.time()
	local success, result = pcall(function()
		return store:UpdateAsync(keyFor(player), function(oldValue)
			local _, owner = unpackRecord(oldValue)
			if owner and owner ~= sessionId then
				conflict = true
				return nil
			end
			return {
				Data = safeData,
				_SessionId = if releaseLock then nil else sessionId,
				_LastSeen = now,
			}
		end)
	end)
	if not success or conflict or result == nil then
		player:SetAttribute("FactoryDataSaveError", if conflict then "Session ownership changed" else "Data store unavailable")
		AnalyticsService.record(player, "DataSaveFailure")
		if not success then
			warn(`Tiny Factory data save failed for {player.UserId}: {result}`)
		end
		return
	end
	player:SetAttribute("FactoryDataSaved", true)
end

local function refreshLock(player: Player)
	local sessionId = sessionIds[player]
	if not sessionId or not loadedPlayers[player] then
		return
	end
	local conflict = false
	local success = pcall(function()
		store:UpdateAsync(keyFor(player), function(oldValue)
			local data, owner = unpackRecord(oldValue)
			if owner ~= sessionId then
				conflict = true
				return nil
			end
			return {
				Data = SaveSchema.sanitize(data),
				_SessionId = sessionId,
				_LastSeen = os.time(),
			}
		end)
	end)
	if not success or conflict then
		loadedPlayers[player] = nil
		setLoadStatus(player, false, true, "Session ownership changed")
	end
end

function DataService.start()
	if started then
		return
	end
	started = true
	local opened, result = pcall(function()
		return DataStoreService:GetDataStore("TinyFactory_PlayerData_v1")
	end)
	if opened then
		store = result
	else
		warn(`Tiny Factory saving is unavailable in this place: {result}`)
	end
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		savePlayer(player, true)
		loadedPlayers[player] = nil
		sessionIds[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			savePlayer(player, true)
		end
	end)
	RunService.Heartbeat:Connect(function(deltaTime)
		lockRefreshAccumulator += deltaTime
		if lockRefreshAccumulator < 60 then
			return
		end
		lockRefreshAccumulator = 0
		for player in pairs(loadedPlayers) do
			refreshLock(player)
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return DataService
