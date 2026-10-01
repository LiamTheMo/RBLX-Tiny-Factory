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

function EconomyRules.getRarityFromOdds(denominator: any): string?
	if type(denominator) ~= "number" or denominator < 1 then
		return nil
	end
	for _, band in ipairs(EconomyConfig.RarityOddsBands) do
		if denominator <= band.MaxDenominator then
			return band.Name
		end
	end
	return nil
end

function EconomyRules.getTotalWeight(weights: { [string]: number }): number
	local total = 0
	for _, weight in pairs(weights) do
		if type(weight) == "number" and weight > 0 and weight < math.huge then total += weight end
	end
	return total
end

function EconomyRules.weightedPick(weights: { [string]: number }, roll: number): string?
	if type(roll) ~= "number" or roll ~= roll or roll < 0 then return nil end
	local total = EconomyRules.getTotalWeight(weights)
	if total <= 0 or roll >= total then return nil end
	local cursor = 0
	for key, weight in pairs(weights) do
		if type(weight) == "number" and weight > 0 and weight < math.huge then
			cursor += weight
			if roll < cursor then return key end
		end
	end
	return nil
end

function EconomyRules.getLuckAdjustedRarityWeights(rarityWeights: { [string]: number }, luckMultiplier: any): { [string]: number }
	local multiplier = if type(luckMultiplier) == "number" and luckMultiplier == luckMultiplier
		then math.clamp(luckMultiplier, 1, EconomyConfig.MaxLuckMultiplier) else 1
	local adjusted = {}
	for rarity, weight in pairs(rarityWeights) do
		local bias = 0
		for _, band in ipairs(EconomyConfig.RarityOddsBands) do
			if band.Name == rarity then bias = math.clamp(band.LuckBias or 0, 0, 1); break end
		end
		adjusted[rarity] = weight * (1 + (multiplier - 1) * bias)
	end
	return adjusted
end

function EconomyRules.getRollPoolTotalChance(rollPool: { [number]: any }, rarity: string?): number
	local total = 0
	for _, definition in ipairs(rollPool) do
		if definition.Rollable == true and (rarity == nil or definition.Rarity == rarity) then
			local weight = definition.RollWeight
			if type(weight) == "number" and weight > 0 then total += weight end
		end
	end
	return total
end

function EconomyRules.pickMachineId(rollPool: { [number]: any }, roll: number, rarity: string?): string?
	if type(roll) ~= "number" or roll ~= roll or roll < 0 then return nil end
	local total = EconomyRules.getRollPoolTotalChance(rollPool, rarity)
	if total <= 0 or roll >= total then return nil end
	local cursor = 0
	for _, definition in ipairs(rollPool) do
		if definition.Rollable == true and (rarity == nil or definition.Rarity == rarity) then
			local weight = definition.RollWeight or 0
			if weight > 0 then
				cursor += weight
				if roll < cursor then return definition.Id end
			end
		end
	end
	return nil
end

function EconomyRules.getMachineOddsDenominator(machineId: any, rollPool: { [number]: any }, rarityWeights: { [string]: number }?): number?
	if type(machineId) ~= "string" or type(rollPool) ~= "table" then return nil end
	local weights = rarityWeights or EconomyConfig.RarityWeights
	local rarityTotal = EconomyRules.getTotalWeight(weights)
	local definition = nil
	for _, candidate in ipairs(rollPool) do
		if candidate.Id == machineId and candidate.Rollable == true then definition = candidate; break end
	end
	if not definition or rarityTotal <= 0 then return nil end
	local rarityWeight = weights[definition.Rarity]
	local innerWeight = definition.RollWeight
	local innerTotal = EconomyRules.getRollPoolTotalChance(rollPool, definition.Rarity)
	if not rarityWeight or not innerWeight or innerWeight <= 0 or innerTotal <= 0 then return nil end
	return (rarityTotal * innerTotal) / (rarityWeight * innerWeight)
end

function EconomyRules.getMachineRarity(machineId: any, rollPool: { [number]: any }): string?
	if type(machineId) ~= "string" then return nil end
	for _, definition in ipairs(rollPool) do
		if definition.Id == machineId and definition.Rollable == true then return definition.Rarity end
	end
	return nil
end

function EconomyRules.shouldPlayUltraRareCutscene(oddsDenominator: any): boolean
	return type(oddsDenominator) == "number"
		and oddsDenominator > EconomyConfig.UltraRareCutscene.MinimumOddsDenominator
end

function EconomyRules.getMachineOddsLabel(machineId: any, rollPool: { [number]: any }, rarityWeights: { [string]: number }?): string?
	if type(machineId) ~= "string" or type(rollPool) ~= "table" then
		return nil
	end
	local denominator
	for _, definition in ipairs(rollPool) do
		if definition.Id == machineId and type(definition.RollChance) == "number" and definition.RollChance > 0 then
			denominator = 100 / definition.RollChance
			break
		end
	end
	denominator = denominator or EconomyRules.getMachineOddsDenominator(machineId, rollPool, rarityWeights)
	if not denominator then return nil end
	local rounded = math.floor(denominator * 10 + 0.5) / 10
	local denominatorText = if rounded % 1 == 0 then string.format("%.0f", rounded) else string.format("%.1f", rounded)
	return "1/" .. denominatorText
end

function EconomyRules.getLuckAdjustedRollPool(rollPool: { [number]: any }, luckMultiplier: any): { [number]: any }
	local adjustedWeights = EconomyRules.getLuckAdjustedRarityWeights(EconomyConfig.RarityWeights, luckMultiplier)
	local rarityTotal = EconomyRules.getTotalWeight(adjustedWeights)
	local result = {}
	for _, definition in ipairs(rollPool) do
		local rarityWeight = adjustedWeights[definition.Rarity] or 0
		local innerTotal = EconomyRules.getRollPoolTotalChance(rollPool, definition.Rarity)
		local innerWeight = definition.RollWeight or 0
		local copy = table.clone(definition)
		copy.RollChance = if rarityTotal > 0 and innerTotal > 0 then 100 * rarityWeight / rarityTotal * innerWeight / innerTotal else 0
		table.insert(result, copy)
	end
	return result
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

function EconomyRules.getResaleValue(rarity: any): number
	return 0
end

return EconomyRules
