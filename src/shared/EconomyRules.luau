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

function EconomyRules.getRollPoolTotalChance(rollPool: { [number]: any }): number
	if type(rollPool) ~= "table" then
		return 0
	end
	local totalChance = 0
	for _, definition in ipairs(rollPool) do
		if type(definition) == "table" and definition.Rollable == true and type(definition.RollChance) == "number" and definition.RollChance > 0 then
			totalChance += definition.RollChance
		end
	end
	return totalChance
end

-- Copy definitions before changing weights so machine configuration stays immutable.
function EconomyRules.getLuckAdjustedRollPool(rollPool: { [number]: any }, luckMultiplier: any): { [number]: any }
	if type(rollPool) ~= "table" then
		return {}
	end
	if type(luckMultiplier) ~= "number" or luckMultiplier ~= luckMultiplier then
		luckMultiplier = 1
	end
	luckMultiplier = math.clamp(luckMultiplier, 1, EconomyConfig.MaxLuckMultiplier)
	if luckMultiplier <= 1 then
		return rollPool
	end
	local adjustedPool = {}
	for _, definition in ipairs(rollPool) do
		local adjusted = {}
		for key, value in pairs(definition) do
			adjusted[key] = value
		end
		if definition.Rollable == true and type(definition.RollChance) == "number" and definition.RollChance > 0 then
			local luckBias = 0
			for _, band in ipairs(EconomyConfig.RarityOddsBands) do
				if band.Name == definition.Rarity then
					luckBias = math.clamp(band.LuckBias or 0, 0, 1)
					break
				end
			end
			adjusted.RollChance = definition.RollChance * (1 + (luckMultiplier - 1) * luckBias)
		end
		table.insert(adjustedPool, adjusted)
	end
	return adjustedPool
end

function EconomyRules.getMachineOddsDenominator(machineId: any, rollPool: { [number]: any }): number?
	if type(machineId) ~= "string" or type(rollPool) ~= "table" then
		return nil
	end
	local totalChance = EconomyRules.getRollPoolTotalChance(rollPool)
	local machineChance: number? = nil
	for _, definition in ipairs(rollPool) do
		if type(definition) == "table" and definition.Rollable == true and type(definition.RollChance) == "number" and definition.RollChance > 0 and definition.Id == machineId then
			machineChance = definition.RollChance
			break
		end
	end
	if not machineChance or totalChance <= 0 then
		return nil
	end
	return totalChance / machineChance
end

function EconomyRules.getMachineRarity(machineId: any, rollPool: { [number]: any }): string?
	local denominator = EconomyRules.getMachineOddsDenominator(machineId, rollPool)
	return denominator and EconomyRules.getRarityFromOdds(denominator) or nil
end

function EconomyRules.shouldPlayUltraRareCutscene(oddsDenominator: any): boolean
	return type(oddsDenominator) == "number"
		and oddsDenominator > EconomyConfig.UltraRareCutscene.MinimumOddsDenominator
end

function EconomyRules.getMachineOddsLabel(machineId: any, rollPool: { [number]: any }): string?
	if type(machineId) ~= "string" or type(rollPool) ~= "table" then
		return nil
	end
	local denominator = EconomyRules.getMachineOddsDenominator(machineId, rollPool)
	if not denominator then
		return nil
	end
	local rounded = math.floor(denominator * 10 + 0.5) / 10
	local denominatorText = if rounded % 1 == 0 then string.format("%.0f", rounded) else string.format("%.1f", rounded)
	return "1/" .. denominatorText
end

function EconomyRules.pickMachineId(rollPool: { [number]: any }, roll: number): string?
	if type(rollPool) ~= "table" or type(roll) ~= "number" or roll < 0 then
		return nil
	end
	local totalChance = EconomyRules.getRollPoolTotalChance(rollPool)
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
	return 0
end

return EconomyRules
