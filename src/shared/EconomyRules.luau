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

-- Returns the per-machine chance as a reciprocal (1 in N rolls), rounded to one decimal.
function EconomyRules.getMachineOddsLabel(rarity: any, rollPool: { [number]: any }): string?
	if type(rarity) ~= "string" or type(rollPool) ~= "table" then
		return nil
	end
	local weights = EconomyConfig.RarityWeights :: { [string]: number }
	local rarityWeight = weights[rarity]
	if not rarityWeight or rarityWeight <= 0 then
		return nil
	end

	local machinesInRarity = 0
	for _, definition in ipairs(rollPool) do
		if type(definition) == "table" and definition.Rollable == true and definition.Rarity == rarity then
			machinesInRarity += 1
		end
	end
	if machinesInRarity == 0 then
		return nil
	end

	local totalWeight = 0
	for _, weight in pairs(weights) do
		if weight > 0 then
			totalWeight += weight
		end
	end
	if totalWeight <= 0 then
		return nil
	end

	local rollsPerMachine = totalWeight * machinesInRarity / rarityWeight
	local rounded = math.floor(rollsPerMachine * 10 + 0.5) / 10
	local denominator = if rounded % 1 == 0 then string.format("%.0f", rounded) else string.format("%.1f", rounded)
	return "1/" .. denominator
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

function EconomyRules.getResaleValue(rarity: any): number
	-- Free rolls cannot be resold for Coins without creating an unlimited mint.
	return 0
end

return EconomyRules
