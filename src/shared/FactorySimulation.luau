--!strict

local FactoryConfig
if script ~= nil then
	FactoryConfig = require(script.Parent.FactoryConfig)
else
	FactoryConfig = require("./FactoryConfig")
end

local MachineDefinitions
if script ~= nil then
	MachineDefinitions = require(script.Parent.MachineDefinitions)
else
	MachineDefinitions = require("./MachineDefinitions")
end

local CubeTypeDefinitions
if script ~= nil then
	CubeTypeDefinitions = require(script.Parent.CubeTypeDefinitions)
else
	CubeTypeDefinitions = require("./CubeTypeDefinitions")
end

local NumberFormatter
if script ~= nil then
	NumberFormatter = require(script.Parent.NumberFormatter)
else
	NumberFormatter = require("./NumberFormatter")
end

local SaleValueRules
if script ~= nil then
	SaleValueRules = require(script.Parent.SaleValueRules)
else
	SaleValueRules = require("./SaleValueRules")
end

type ValueModifierLayer = {
	AdditiveBonus: number?,
	Multiplier: number?,
}

type Item = {
	Id: number,
	Value: number,
	BaseValue: number,
	ModifierLabels: { string },
	SlotIndex: number,
	TimeRemaining: number,
	SourceMachineId: string,
	TypeId: string,
	TypeModifiers: ValueModifierLayer,
	VisualState: string,
	SizeScale: number,
	TravelScale: number,
	ReadyForSale: boolean,
}

export type SimulationConfig = {
	MaxActiveItems: number?,
	MaxItemValue: number?,
	MaxCoins: number?,
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
		maxCoins = provided.MaxCoins or FactoryConfig.MaxCoins,
		spawnIntervalSeconds = provided.SpawnIntervalSeconds or FactoryConfig.SpawnIntervalSeconds,
		travelTimePerSlotSeconds = provided.TravelTimePerSlotSeconds or FactoryConfig.TravelTimePerSlotSeconds,
		maxCatchUpSpawnsPerStep = provided.MaxCatchUpSpawnsPerStep or FactoryConfig.MaxCatchUpSpawnsPerStep,
		usesConfiguredSpawnInterval = provided.SpawnIntervalSeconds ~= nil,
		timeSeconds = 0,
		nextSpawnAt = 0,
		nextSaleAt = 0,
		nextItemId = 0,
		coins = 0,
		activeItems = {},
		pendingItems = {},
		producedItems = 0,
		processedItems = 0,
		soldItems = 0,
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
		Value = math.min(producer.OutputValue or 1, self.maxItemValue),
		BaseValue = math.min(producer.OutputValue or 1, self.maxItemValue),
		ModifierLabels = {},
		SlotIndex = 1,
		TimeRemaining = self.travelTimePerSlotSeconds,
		SourceMachineId = producer.Id,
		TypeId = producer.OutputType or "Standard",
		TypeModifiers = table.clone(producer.TypeModifiers or {}),
		VisualState = "Base",
		SizeScale = 1,
		TravelScale = 1,
		ReadyForSale = false,
	})
end

function FactorySimulation:_processItemAtSlot(item: Item): boolean
	local machineId = self.route[item.SlotIndex]
	local definition = machineId and MachineDefinitions.get(machineId)
	if not definition then
		return true
	end

	if definition.Category == "Processor" then
		local behavior = definition.Behavior or "MultiplyValue"
		local label = definition.DisplayName
		if behavior == "MultiplyValue" or behavior == "Goldenize" then
			label ..= " ×" .. NumberFormatter.format(definition.Multiplier or 1)
		elseif behavior == "TypeMultiplier" then
			label ..= " ×" .. NumberFormatter.format(definition.Multiplier or 1)
		elseif behavior == "ScaleVisual" then
			label ..= " · size ×" .. NumberFormatter.format(definition.SizeScale or 1)
		elseif behavior == "AdjustThroughput" then
			label ..= " · speed ×" .. NumberFormatter.format(1 / (definition.TravelScale or 1))
		elseif behavior == "RandomMultiplier" then
			label ..= " ×" .. NumberFormatter.format(if item.Id % 2 == 0 then 3 else 0.5)
		end
		if #item.ModifierLabels < FactoryConfig.MaxItemModifierLabels then
			table.insert(item.ModifierLabels, label)
		end
		if behavior == "MultiplyValue" then
			item.Value = math.min(item.Value * (definition.Multiplier or 1), self.maxItemValue)
		elseif behavior == "TypeMultiplier" then
			if item.TypeId == definition.TypeFilter then
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
					BaseValue = item.BaseValue,
					ModifierLabels = table.clone(item.ModifierLabels),
					SlotIndex = item.SlotIndex + 1,
					TimeRemaining = self.travelTimePerSlotSeconds,
					SourceMachineId = item.SourceMachineId,
					TypeId = item.TypeId,
					TypeModifiers = table.clone(item.TypeModifiers),
					VisualState = item.VisualState,
					SizeScale = item.SizeScale,
					TravelScale = item.TravelScale,
					ReadyForSale = false,
				})
			end
		elseif behavior == "Goldenize" then
			item.Value = math.min(item.Value * (definition.Multiplier or 1), self.maxItemValue)
			item.VisualState = definition.VisualState or "Golden"
		elseif behavior == "RandomMultiplier" then
			local chance = definition.BonusChance
			local multiplier = if chance == nil
				then (if item.Id % 2 == 0 then 3 else 0.5)
				else (if chance > 0 and item.Id % math.max(1, math.floor(1 / chance + 0.5)) == 0 then definition.BonusMultiplier or 2 else 1)
			if multiplier ~= 1 then
				item.Value = math.max(1, math.min(math.floor(item.Value * multiplier * 100 + 0.5) / 100, self.maxItemValue))
			end
		end
		self.processedItems += 1
	elseif definition.Category == "Seller" then
		item.ReadyForSale = true
		item.TimeRemaining = 0
	end

	return false
end

function FactorySimulation:_advanceItem(item: Item, deltaTime: number): boolean
	if item.ReadyForSale then
		return false
	end
	local currentDefinition = MachineDefinitions.get(self.route[item.SlotIndex])
	if currentDefinition and currentDefinition.Category == "Seller" then
		item.ReadyForSale = true
		item.TimeRemaining = 0
		return false
	end

	item.TimeRemaining -= deltaTime
	while item.TimeRemaining <= 1e-9 do
		if self:_processItemAtSlot(item) then
			return true
		end
		if item.ReadyForSale then
			return false
		end

		item.SlotIndex += 1
		if item.SlotIndex > #self.route then
			-- A valid Phase 1 route always has a seller. This guard prevents a bad
			-- definition from retaining an item forever if the route changes later.
			return true
		end
		local nextDefinition = MachineDefinitions.get(self.route[item.SlotIndex])
		if nextDefinition and nextDefinition.Category == "Seller" then
			item.ReadyForSale = true
			item.TimeRemaining = 0
			return false
		end

		item.TimeRemaining += self.travelTimePerSlotSeconds * item.TravelScale
		item.TravelScale = 1
	end
	return false
end

local function sellerModifiersFor(item: Item, seller: any, soldItems: number): ValueModifierLayer
	local modifiers = table.clone(seller.SaleModifiers or { AdditiveBonus = 0, Multiplier = 1 })
	local payoutMultiplier = 1
	local behavior = seller.Behavior or "Payout"
	if behavior == "ConditionalPayout" and item.Value >= (seller.MinimumValue or math.huge) then
		payoutMultiplier = seller.PayoutMultiplier or 1
	elseif behavior == "TypePayout" and item.TypeId == seller.TypeFilter then
		payoutMultiplier = seller.PayoutMultiplier or 1
	elseif behavior == "ChancePayout" then
		local denominator = math.max(1, math.floor(1 / math.max(seller.BonusChance or 0, 0.000001) + 0.5))
		payoutMultiplier = if item.Id % denominator == 0 then seller.BonusMultiplier or 1 else 1
	elseif behavior == "StreakPayout" then
		payoutMultiplier = if (soldItems + 1) % (seller.BonusEvery or math.huge) == 0 then seller.BonusMultiplier or 1 else 1
	elseif behavior == "RarityPayout" then
		local cubeType = CubeTypeDefinitions.get(item.TypeId)
		if cubeType and (CUBE_RARITY_RANKS[cubeType.Rarity] or 0) >= (CUBE_RARITY_RANKS[seller.RequiredCubeRarity or "Epic"] or 4) then
			payoutMultiplier = seller.PayoutMultiplier or 1
		end
	elseif behavior == "Payout" then
		payoutMultiplier = seller.PayoutMultiplier or 1
	end
	modifiers.Multiplier = (modifiers.Multiplier or 1) * payoutMultiplier
	return modifiers
end

function FactorySimulation:getSaleModifiers(itemId: number): ValueModifierLayer?
	local seller = MachineDefinitions.get(self.route[#self.route])
	if not seller or seller.Category ~= "Seller" then return nil end
	for _, item in ipairs(self.activeItems) do
		if item.Id == itemId then return sellerModifiersFor(item, seller, self.soldItems) end
	end
	return nil
end

function FactorySimulation:sellItem(itemId: any, buffModifiers: ValueModifierLayer?): (boolean, number?)
	if type(itemId) ~= "number" or itemId % 1 ~= 0 or itemId < 1 then
		return false, nil
	end

	local seller = MachineDefinitions.get(self.route[#self.route])
	if not seller or seller.Category ~= "Seller" then
		return false, nil
	end

	if self.timeSeconds < self.nextSaleAt then
		return false, nil
	end

	for index, item in ipairs(self.activeItems) do
		if item.Id == itemId then
			if not item.ReadyForSale then
				return false, nil
			end

			local saleModifiers = sellerModifiersFor(item, seller, self.soldItems)
			local saleValue = SaleValueRules.calculate(
				item.Value,
				item.TypeModifiers,
				buffModifiers,
				saleModifiers,
				self.maxItemValue
			)
			if not saleValue then
				return false, nil
			end

			local credited = math.min(saleValue, math.max(0, self.maxCoins - self.coins))
			table.remove(self.activeItems, index)
			self.coins += credited
			self.totalValueSold = math.min(self.totalValueSold + credited, self.maxCoins)
			self.nextSaleAt = self.timeSeconds + (seller.SaleIntervalSeconds or 0)
			self.soldItems += 1
			return true, credited
		end
	end

	return false, nil
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
	self.pendingItems = {}
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
	table.clear(self.pendingItems)
	return self.producedItems > producedBefore, self.soldItems > soldBefore
end

function FactorySimulation:getCoins(): number
	return self.coins
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

function FactorySimulation:grantCoins(amount: number): boolean
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false
	end
	self.coins = math.min(self.coins + amount, self.maxCoins)
	return true
end

function FactorySimulation:setCoins(amount: any): boolean
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false
	end
	self.coins = math.min(amount, self.maxCoins)
	return true
end

function FactorySimulation:getActiveItemsForDebug(): { Item }
	local result = {}
	for index, item in ipairs(self.activeItems) do
		result[index] = {
			Id = item.Id,
			Value = item.Value,
			BaseValue = item.BaseValue,
			ModifierLabels = table.clone(item.ModifierLabels),
			SlotIndex = item.SlotIndex,
			TimeRemaining = item.TimeRemaining,
			SourceMachineId = item.SourceMachineId,
			TypeId = item.TypeId,
			TypeModifiers = table.clone(item.TypeModifiers),
			VisualState = item.VisualState,
			SizeScale = item.SizeScale,
			TravelScale = item.TravelScale,
			ReadyForSale = item.ReadyForSale,
		}
	end
	return result
end

function FactorySimulation.validateConfiguration(config: SimulationConfig?): (boolean, string?)
	local provided = config or {}
	local maxActiveItems = provided.MaxActiveItems or FactoryConfig.MaxActiveItems
	local maxItemValue = provided.MaxItemValue or FactoryConfig.MaxItemValue
	local maxCoins = provided.MaxCoins or FactoryConfig.MaxCoins
	local spawnInterval = provided.SpawnIntervalSeconds or FactoryConfig.SpawnIntervalSeconds
	local travelTime = provided.TravelTimePerSlotSeconds or FactoryConfig.TravelTimePerSlotSeconds
	local maxCatchUp = provided.MaxCatchUpSpawnsPerStep or FactoryConfig.MaxCatchUpSpawnsPerStep

	if not isFinitePositive(maxActiveItems) or maxActiveItems % 1 ~= 0 then
		return false, "MaxActiveItems must be a positive integer"
	end
	if not isFinitePositive(maxItemValue) then
		return false, "MaxItemValue must be finite and positive"
	end
	if not isFinitePositive(maxCoins) or maxCoins % 1 ~= 0 or maxCoins > FactoryConfig.MaxCoins then
		return false, "MaxCoins must be a positive safe integer"
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
