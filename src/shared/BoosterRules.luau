--!strict

local BoosterConfig
local EconomyConfig
if script ~= nil then
	BoosterConfig = require(script.Parent.BoosterConfig)
	EconomyConfig = require(script.Parent.EconomyConfig)
else
	BoosterConfig = require("./BoosterConfig")
	EconomyConfig = require("./EconomyConfig")
end

local BoosterRules = {}

function BoosterRules.get(boosterId: any): any?
	if type(boosterId) ~= "string" then
		return nil
	end
	for _, definition in ipairs(BoosterConfig.Definitions) do
		if definition.Id == boosterId then
			return definition
		end
	end
	return nil
end

function BoosterRules.getTotalSpawnWeight(): number
	local totalWeight = 0
	for _, definition in ipairs(BoosterConfig.Definitions) do
		if type(definition.SpawnWeight) == "number" and definition.SpawnWeight > 0 then
			totalWeight += definition.SpawnWeight
		end
	end
	return totalWeight
end

function BoosterRules.pickBoosterId(roll: any): string?
	local totalWeight = BoosterRules.getTotalSpawnWeight()
	if type(roll) ~= "number" or roll < 0 or roll >= totalWeight then
		return nil
	end
	local cursor = 0
	for _, definition in ipairs(BoosterConfig.Definitions) do
		if type(definition.SpawnWeight) == "number" and definition.SpawnWeight > 0 then
			cursor += definition.SpawnWeight
			if roll < cursor then
				return definition.Id
			end
		end
	end
	return nil
end

function BoosterRules.validate(): (boolean, string?)
	if type(BoosterConfig.SpawnIntervalSeconds) ~= "number" or BoosterConfig.SpawnIntervalSeconds <= 0
		or type(BoosterConfig.MaxActiveDropsPerFactory) ~= "number" or BoosterConfig.MaxActiveDropsPerFactory < 1
		or type(BoosterConfig.MaxActiveDropsWorldwide) ~= "number" or BoosterConfig.MaxActiveDropsWorldwide < 1
		or type(BoosterConfig.DespawnAfterSeconds) ~= "number" or BoosterConfig.DespawnAfterSeconds <= 0
		or type(BoosterConfig.MaxLuckDurationSeconds) ~= "number" or BoosterConfig.MaxLuckDurationSeconds < 1 then
		return false, "Booster spawn limits must be positive"
	end
	local bounds = BoosterConfig.SpawnBounds
	if type(bounds) ~= "table" or bounds.MinX >= bounds.MaxX or bounds.MinZ >= bounds.MaxZ or bounds.Height < 0 then
		return false, "Booster spawn bounds are invalid"
	end
	local seenIds: { [string]: boolean } = {}
	for _, definition in ipairs(BoosterConfig.Definitions) do
		if type(definition.Id) ~= "string" or definition.Id == "" or seenIds[definition.Id] then
			return false, "Booster IDs must be non-empty and unique"
		end
		seenIds[definition.Id] = true
		if type(definition.DisplayName) ~= "string" or definition.DisplayName == "" or type(definition.SpawnWeight) ~= "number" or definition.SpawnWeight <= 0 then
			return false, "Boosters need a name and positive spawn weight"
		end
		local color = definition.Color
		if type(color) ~= "table" or #color ~= 3 then
			return false, "Booster colors must be RGB triples"
		end
		for _, channel in ipairs(color) do
			if type(channel) ~= "number" or channel % 1 ~= 0 or channel < 0 or channel > 255 then
				return false, "Booster RGB channels must be integers from 0 to 255"
			end
		end
		local effect = definition.Effect
		if type(effect) ~= "table" then
			return false, "Each booster needs an effect"
		elseif effect.Kind == "Coins" then
			if type(effect.Amount) ~= "number" or effect.Amount % 1 ~= 0 or effect.Amount < 1 or effect.Amount > 100000 then
				return false, "Coin booster amounts must be bounded positive integers"
			end
		elseif effect.Kind == "Luck" then
			if type(effect.Multiplier) ~= "number" or effect.Multiplier < 1 or effect.Multiplier > EconomyConfig.MaxLuckMultiplier
				or type(effect.DurationSeconds) ~= "number" or effect.DurationSeconds < 1 or effect.DurationSeconds > BoosterConfig.MaxLuckDurationSeconds then
				return false, "Luck booster strength or duration is outside configured limits"
			end
		else
			return false, "Booster effect kind is not supported"
		end
	end
	if BoosterRules.getTotalSpawnWeight() <= 0 then
		return false, "At least one weighted booster is required"
	end
	return true
end

return BoosterRules
