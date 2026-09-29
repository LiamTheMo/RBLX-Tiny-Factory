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

-- Returns the first configured rarity band whose inclusive odds limit contains this reciprocal chance.
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

-- RollChance values are percentage weights whose configured total is 100.
function EconomyRules.getMachineOddsLabel(machineId: any, rollPool: { [number]: any }): string?
	if type(machineId) ~= "string" or type(rollPool) ~= "table" then
		return nil
	end

	local totalChance = 0
	local machineChance: number? = nil
	for _, definition in ipairs(rollPool) do
		if type(definition) == "table" and definition.Rollable == true and type(definition.RollChance) == "number" and definition.RollChance > 0 then
			totalChance += definition.RollChance
			if definition.Id == machineId then
				machineChance = definition.RollChance
			end
		end
	end
	if not machineChance or totalChance <= 0 then
		return nil
	end

	local denominator = totalChance / machineChance
	local rounded = math.floor(denominator * 10 + 0.5) / 10
	local denominatorText = if rounded % 1 == 0 then string.format("%.0f", rounded) else string.format("%.1f", rounded)
	return "1/" .. denominatorText
end

-- Selects one machine from its own RollChance weight. `roll` must be in [0, total chance).
function EconomyRules.pickMachineId(rollPool: { [number]: any }, roll: number): string?
	if type(rollPool) ~= "table" or type(roll) ~= "number" or roll < 0 then
		return nil
	end

	local totalChance = 0
	for _, definition in ipairs(rollPool) do
		if type(definition) == "table" and definition.Rollable == true and type(definition.RollChance) == "number" and definition.RollChance > 0 then
			totalChance += definition.RollChance
		end
	end
	if totalChance <= 0 or roll >= totalChance then
		return nil
	end

	local cursor = 0
	local lastMachineId: string? = nil
	for _, definition in ipairs(rollPool) do
		if type(definition) == "table" and definition.Rollable == true and type(definition.RollChance) == "number" and definition.RollChance > 0 then
			cursor += definition.RollChance
			lastMachineId = definition.Id
			if roll < cursor then
				return definition.Id
			end
		end
	end
	return lastMachineId
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
	-- Free rolls cannot be resold for Coins without creating an unlimited mint.
	return 0
end

return EconomyRules
