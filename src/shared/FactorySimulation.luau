--!strict

local FactoryConfig
if script ~= nil then
	FactoryConfig = require(script.Parent.FactoryConfig)
else
	FactoryConfig = require("./FactoryConfig")
end

local MachineDefinitions
local CubeTypeDefinitions
if script ~= nil then
	MachineDefinitions = require(script.Parent.MachineDefinitions)
	CubeTypeDefinitions = require(script.Parent.CubeTypeDefinitions)
else
	MachineDefinitions = require("./MachineDefinitions")
	CubeTypeDefinitions = require("./CubeTypeDefinitions")
end

type Item = {
	Id: number,
	Value: number,
	SlotIndex: number,
	TimeRemaining: number,
	SourceMachineId: string,
	CubeType: string,
	VisualState: string,
	SizeScale: number,
	TravelScale: number,
	SellerProcessingStarted: boolean,
	SaleDueAt: number?,
}

export type SimulationConfig = {
	MaxActiveItems: number?,
	MaxItemValue: number?,
	SpawnIntervalSeconds: number?,
	TravelTimePerSlotSeconds: number?,
	MaxCatchUpSpawnsPerStep: number?,
	Route: { string }?,
}

export type Snapshot = {
	TimeSeconds: number,
	Coins: number,
	ActiveItems: number,
	ProducedItems: number,
	ProcessedItems: number,
	SoldItems: number,
	DroppedItemsAtCap: number,
	SkippedCatchUpSpawns: number,
	TotalValueSold: number,
	Route: { string },
}

export type VisualItem = {
	Id: number,
	Value: number,
	SlotIndex: number,
	TimeRemaining: number,
	CubeType: string,
	VisualState: string,
	SizeScale: number,
}

local FactorySimulation = {}
FactorySimulation.__index = FactorySimulation
local CUBE_RARITY_RANKS = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

local function isFinitePositive(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	return value == value and value < math.huge and value > 0
end

local function copyRoute(route: { string }): { string }
	local result = {}
	for index, machineId in ipairs(route) do
		result[index] = machineId
	end
	return result
end

function FactorySimulation.new(config: SimulationConfig?): any
	local provided = config or {}
	local configurationValid, configurationError = FactorySimulation.validateConfiguration(provided)
	assert(configurationValid, configurationError or "Invalid factory simulation configuration")
	local self = setmetatable({
		maxActiveItems = provided.MaxActiveItems or FactoryConfig.MaxActiveItems,
		maxItemValue = provided.MaxItemValue or FactoryConfig.MaxItemValue,
		spawnIntervalSeconds = provided.SpawnIntervalSeconds or FactoryConfig.SpawnIntervalSeconds,
		travelTimePerSlotSeconds = provided.TravelTimePerSlotSeconds or FactoryConfig.TravelTimePerSlotSeconds,
		maxCatchUpSpawnsPerStep = provided.MaxCatchUpSpawnsPerStep or FactoryConfig.MaxCatchUpSpawnsPerStep,
		usesConfiguredSpawnInterval = provided.SpawnIntervalSeconds ~= nil,
		timeSeconds = 0,
		nextSpawnAt = 0,
		nextItemId = 0,
		coins = 0,
		activeItems = {},
		pendingItems = {},
		producedItems = 0,
		processedItems = 0,
		soldItems = 0,
		sellerNextAvailableAt = 0,
		droppedItemsAtCap = 0,
		skippedCatchUpSpawns = 0,
		totalValueSold = 0,
		route = {},
	}, FactorySimulation)

	self:setRoute(provided.Route or FactoryConfig.DefaultRoute)
	return self
end

function FactorySimulation:setRoute(route: { string })
	assert(type(route) == "table" and #route > 0, "A route must contain at least one machine")

	local producerCount = 0
	local sellerCount = 0
	local nextRoute = {}
	for index, machineId in ipairs(route) do
		local definition = MachineDefinitions.get(machineId)
		assert(definition ~= nil, `Unknown machine in route: {machineId}`)
		if definition.Category == "Producer" then
			producerCount += 1
		elseif definition.Category == "Seller" then
			sellerCount += 1
		end
		nextRoute[index] = machineId
	end

	assert(producerCount == 1, "Phase 1 requires exactly one producer")
	assert(sellerCount == 1, "Phase 1 requires exactly one seller")
	local firstDefinition = MachineDefinitions.get(nextRoute[1])
	local lastDefinition = MachineDefinitions.get(nextRoute[#nextRoute])
	assert(firstDefinition and firstDefinition.Category == "Producer", "Phase 1 routes must begin with a producer")
	assert(lastDefinition and lastDefinition.Category == "Seller", "Phase 1 routes must end with a seller")
	self.route = nextRoute
	if not self.usesConfiguredSpawnInterval then
		self.spawnIntervalSeconds = firstDefinition and firstDefinition.SpawnInterval or FactoryConfig.SpawnIntervalSeconds
	end
end

function FactorySimulation:_spawnItem()
	if #self.activeItems >= self.maxActiveItems then
		self.droppedItemsAtCap += 1
		return
	end

	local producerId = self.route[1]
	local producer = MachineDefinitions.get(producerId)
	assert(producer and producer.Category == "Producer", "A route must begin with a producer")

	self.nextItemId += 1
	self.producedItems += 1
	table.insert(self.activeItems, {
		Id = self.nextItemId,
		Value = math.min((producer.OutputValue or 1) * ((CubeTypeDefinitions.get(producer.CubeType or "Standard") or {}).ValueMultiplier or 1), self.maxItemValue),
		SlotIndex = 1,
		TimeRemaining = self.travelTimePerSlotSeconds,
		SourceMachineId = producer.Id,
		CubeType = producer.CubeType or "Standard",
		VisualState = "Base",
		SizeScale = 1,
		TravelScale = 1,
		SellerProcessingStarted = false,
		SaleDueAt = nil,
	})
end

function FactorySimulation:_processItemAtSlot(item: Item): boolean?
	local machineId = self.route[item.SlotIndex]
	local definition = machineId and MachineDefinitions.get(machineId)
	if not definition then
		return true
	end

	if definition.Category == "Processor" then
		local behavior = definition.Behavior or "MultiplyValue"
		if behavior == "MultiplyValue" then
			item.Value = math.min(item.Value * (definition.Multiplier or 1), self.maxItemValue)
		elseif behavior == "TypeMultiplier" then
			if item.CubeType == definition.TypeFilter then
				item.Value = math.min(item.Value * (definition.Multiplier or 1), self.maxItemValue)
			end
		elseif behavior == "ScaleVisual" then
			item.SizeScale = math.min(item.SizeScale * (definition.SizeScale or 1), 4)
		elseif behavior == "SetMaterial" then
			item.VisualState = definition.VisualState or "Painted"
		elseif behavior == "AdjustThroughput" then
			item.TravelScale = math.clamp(item.TravelScale * (definition.TravelScale or 1), 0.25, 1)
		elseif behavior == "DuplicateItem" then
			if item.SlotIndex < #self.route then
				self.nextItemId += 1
				table.insert(self.pendingItems, {
					Id = self.nextItemId,
					Value = item.Value,
					SlotIndex = item.SlotIndex + 1,
					TimeRemaining = self.travelTimePerSlotSeconds,
					SourceMachineId = item.SourceMachineId,
					CubeType = item.CubeType,
					VisualState = item.VisualState,
					SizeScale = item.SizeScale,
					TravelScale = item.TravelScale,
					SellerProcessingStarted = false,
					SaleDueAt = nil,
				})
			end
		elseif behavior == "Goldenize" then
			item.Value = math.min(item.Value * (definition.Multiplier or 1), self.maxItemValue)
			item.VisualState = definition.VisualState or "Golden"
		elseif behavior == "RandomMultiplier" then
			local chance = definition.BonusChance
			if chance == nil then
				local multiplier = if item.Id % 2 == 0 then 3 else 0.5
				item.Value = math.max(1, math.min(math.floor(item.Value * multiplier), self.maxItemValue))
			elseif chance > 0 then
				local denominator = math.max(1, math.floor(1 / chance + 0.5))
				if item.Id % denominator == 0 then
					item.Value = math.min(item.Value * (definition.BonusMultiplier or 2), self.maxItemValue)
				end
			end
		end
		self.processedItems += 1
	elseif definition.Category == "Seller" then
		if not item.SellerProcessingStarted and (definition.SaleIntervalSeconds or 0) > 0 then
			local saleStartsAt = math.max(self.sellerNextAvailableAt, self.timeSeconds)
			item.SaleDueAt = saleStartsAt + (definition.SaleIntervalSeconds or 0)
			self.sellerNextAvailableAt = item.SaleDueAt
			item.SellerProcessingStarted = true
			item.TimeRemaining = item.SaleDueAt - self.timeSeconds
			return nil
		end
		if item.SaleDueAt and self.timeSeconds + 1e-9 < item.SaleDueAt then
			item.TimeRemaining = item.SaleDueAt - self.timeSeconds
			return nil
		end
		local payoutMultiplier = definition.PayoutMultiplier or 1
		local behavior = definition.Behavior or "Payout"
		if behavior == "ConditionalPayout" and item.Value < (definition.MinimumValue or math.huge) then
			payoutMultiplier = 1
		elseif behavior == "TypePayout" and item.CubeType ~= definition.TypeFilter then
			payoutMultiplier = 1
		elseif behavior == "ChancePayout" then
			local chance = definition.BonusChance or 0
			local denominator = math.max(1, math.floor(1 / math.max(chance, 0.000001) + 0.5))
			payoutMultiplier = if item.Id % denominator == 0 then (definition.BonusMultiplier or 1) else 1
		elseif behavior == "StreakPayout" then
			local saleNumber = self.soldItems + 1
			payoutMultiplier = if saleNumber % (definition.BonusEvery or math.huge) == 0 then (definition.BonusMultiplier or 1) else 1
		elseif behavior == "RarityPayout" then
			local cubeType = CubeTypeDefinitions.get(item.CubeType)
			if not cubeType or (CUBE_RARITY_RANKS[cubeType.Rarity] or 0) < (CUBE_RARITY_RANKS[definition.RequiredCubeRarity or "Epic"] or 4) then
				payoutMultiplier = 1
			end
		end
		local payout = math.min(self.maxItemValue, math.max(0.01, math.floor(item.Value * payoutMultiplier * 100 + 0.5) / 100))
		self.coins = math.min(self.coins + payout, self.maxItemValue)
		self.totalValueSold = math.min(self.totalValueSold + payout, self.maxItemValue)
		self.soldItems += 1
		return true
	end

	return false
end

function FactorySimulation:_advanceItem(item: Item, deltaTime: number): boolean
	item.TimeRemaining -= deltaTime
	while item.TimeRemaining <= 1e-9 do
		local consumed = self:_processItemAtSlot(item)
		if consumed == true then
			return true
		elseif consumed == nil then
			return false
		end

		item.SlotIndex += 1
		if item.SlotIndex > #self.route then
			-- A valid Phase 1 route always has a seller. This guard prevents a bad
			-- definition from retaining an item forever if the route changes later.
			return true
		end

		item.TimeRemaining += self.travelTimePerSlotSeconds * item.TravelScale
		item.TravelScale = 1
	end
	return false
end

function FactorySimulation:step(deltaTime: number): (boolean, boolean)
	assert(type(deltaTime) == "number" and deltaTime == deltaTime, "deltaTime must be a number")
	assert(deltaTime >= 0 and deltaTime <= 60, "deltaTime must be between 0 and 60 seconds")
	if deltaTime == 0 then
		return false, false
	end

	local producedBefore = self.producedItems
	local soldBefore = self.soldItems
	self.timeSeconds += deltaTime
	table.clear(self.pendingItems)
	local spawnCount = 0
	while self.timeSeconds >= self.nextSpawnAt do
		if spawnCount >= self.maxCatchUpSpawnsPerStep then
			self.skippedCatchUpSpawns += 1
			self.nextSpawnAt = self.timeSeconds + self.spawnIntervalSeconds
			break
		end
		self:_spawnItem()
		spawnCount += 1
		self.nextSpawnAt += self.spawnIntervalSeconds
	end

	for index = #self.activeItems, 1, -1 do
		local item = self.activeItems[index]
		if self:_advanceItem(item, deltaTime) then
			table.remove(self.activeItems, index)
		end
	end

	for _, item in ipairs(self.pendingItems) do
		if #self.activeItems < self.maxActiveItems then
			table.insert(self.activeItems, item)
		else
			self.droppedItemsAtCap += 1
		end
	end
	return self.producedItems > producedBefore, self.soldItems > soldBefore
end

function FactorySimulation:getSnapshot(): Snapshot
	return {
		TimeSeconds = self.timeSeconds,
		Coins = self.coins,
		ActiveItems = #self.activeItems,
		ProducedItems = self.producedItems,
		ProcessedItems = self.processedItems,
		SoldItems = self.soldItems,
		DroppedItemsAtCap = self.droppedItemsAtCap,
		SkippedCatchUpSpawns = self.skippedCatchUpSpawns,
		TotalValueSold = self.totalValueSold,
		Route = copyRoute(self.route),
	}
end

function FactorySimulation:tryDebitCoins(amount: number): boolean
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false
	end
	if self.coins < amount then
		return false
	end
	self.coins -= amount
	return true
end

function FactorySimulation:getCoins(): number
	return self.coins
end

function FactorySimulation:grantCoins(amount: number): boolean
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false
	end
	self.coins = math.min(self.coins + amount, self.maxItemValue)
	return true
end

function FactorySimulation:setCoins(amount: any): boolean
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false
	end
	self.coins = math.min(amount, self.maxItemValue)
	return true
end

function FactorySimulation:getActiveItemsForVisuals(): { VisualItem }
	local result: { VisualItem } = {}
	for index, item in ipairs(self.activeItems) do
		result[index] = {
			Id = item.Id,
			Value = item.Value,
			SlotIndex = item.SlotIndex,
			TimeRemaining = item.TimeRemaining,
			CubeType = item.CubeType,
			VisualState = item.VisualState,
			SizeScale = item.SizeScale,
		}
	end
	return result
end

function FactorySimulation.validateConfiguration(config: SimulationConfig?): (boolean, string?)
	local provided = config or {}
	local maxActiveItems = provided.MaxActiveItems or FactoryConfig.MaxActiveItems
	local maxItemValue = provided.MaxItemValue or FactoryConfig.MaxItemValue
	local spawnInterval = provided.SpawnIntervalSeconds or FactoryConfig.SpawnIntervalSeconds
	local travelTime = provided.TravelTimePerSlotSeconds or FactoryConfig.TravelTimePerSlotSeconds
	local maxCatchUp = provided.MaxCatchUpSpawnsPerStep or FactoryConfig.MaxCatchUpSpawnsPerStep

	if not isFinitePositive(maxActiveItems) or maxActiveItems % 1 ~= 0 then
		return false, "MaxActiveItems must be a positive integer"
	end
	if not isFinitePositive(maxItemValue) then
		return false, "MaxItemValue must be finite and positive"
	end
	if not isFinitePositive(spawnInterval) or not isFinitePositive(travelTime) then
		return false, "Timing values must be finite and positive"
	end
	if not isFinitePositive(maxCatchUp) or maxCatchUp % 1 ~= 0 then
		return false, "MaxCatchUpSpawnsPerStep must be a positive integer"
	end

	local ok, message = MachineDefinitions.validate()
	if not ok then
		return false, message
	end
	return true
end

return FactorySimulation
