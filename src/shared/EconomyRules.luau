--!strict

local EconomyConfig
if script ~= nil then
	EconomyConfig = require(script.Parent.EconomyConfig)
else
	EconomyConfig = require("./EconomyConfig")
end

local EconomyRules = {}

function EconomyRules.getRollCost(rollCount: any): (number?, string?)
	if type(rollCount) ~= "number" or rollCount < 0 or rollCount % 1 ~= 0 then
		return nil, "Roll count must be a non-negative integer"
	end
	return 0
end

function EconomyRules.getRollCooldownRemaining(nextRollAt: number, now: number): number
	return math.max(0, nextRollAt - now)
end

function EconomyRules.canRoll(nextRollAt: number, now: number, inventoryCount: number): (boolean, string?)
	if EconomyRules.getRollCooldownRemaining(nextRollAt, now) > 0 then
		return false, "Roll cooldown active"
	end
	if inventoryCount >= EconomyConfig.MaxInventoryMachines then
		return false, "Machine inventory is full; recycle a spare first"
	end
	return true
end

function EconomyRules.getCapacityCost(capacity: any): (number?, string?)
	if type(capacity) ~= "number" or capacity < 1 or capacity % 1 ~= 0 then
		return nil, "Capacity must be a positive integer"
	end
	local cost = EconomyConfig.CapacityCosts[capacity]
	if not cost then
		return nil, "Capacity is already at the maximum"
	end
	return cost
end

function EconomyRules.weightedPick(weights: { [string]: number }, roll: number): string?
	if roll < 0 then
		return nil
	end
	local total = 0
	for _, weight in pairs(weights) do
		if weight > 0 then
			total += weight
		end
	end
	if total <= 0 or roll >= total then
		return nil
	end

	local cursor = 0
	for name, weight in pairs(weights) do
		if weight > 0 then
			cursor += weight
			if roll < cursor then
				return name
			end
		end
	end
	return nil
end

function EconomyRules.getMachineRollChances(rarityWeights: { [string]: number }, pool: { any }): { [string]: number }
	local totalRarityWeight = 0
	local itemWeightByRarity: { [string]: number } = {}
	for _, weight in pairs(rarityWeights) do
		if weight > 0 then totalRarityWeight += weight end
	end
	for _, definition in ipairs(pool) do
		local weight = definition.RollWeight
		if definition.Rollable and type(weight) == "number" and weight > 0 then
			itemWeightByRarity[definition.Rarity] = (itemWeightByRarity[definition.Rarity] or 0) + weight
		end
	end
	local chances: { [string]: number } = {}
	for _, definition in ipairs(pool) do
		local rarityWeight = rarityWeights[definition.Rarity] or 0
		local rarityItemWeight = itemWeightByRarity[definition.Rarity] or 0
		local itemWeight = definition.RollWeight or 0
		chances[definition.Id] = if definition.Rollable and totalRarityWeight > 0 and rarityWeight > 0 and rarityItemWeight > 0 then (rarityWeight / totalRarityWeight) * (itemWeight / rarityItemWeight) * 100 else 0
	end
	return chances
end

function EconomyRules.getResaleValue(rarity: any): number
	-- Free rolls cannot be resold for Coins without creating an unlimited mint.
	return 0
end

return EconomyRules
