--!strict

local EconomyConfig
local EconomyRules
if script ~= nil then
	EconomyConfig = require(script.Parent.EconomyConfig)
	EconomyRules = require(script.Parent.EconomyRules)
else
	EconomyConfig = require("./EconomyConfig")
	EconomyRules = require("./EconomyRules")
end

export type MachineCategory = "Producer" | "Processor" | "Seller"

type MachineDefinitionSource = {
	Id: string,
	DisplayName: string,
	Category: MachineCategory,
	Description: string,
	Rarity: string?,
	Rollable: boolean,
	RollChance: number?,
	Behavior: string?,
	SpawnInterval: number?,
	OutputValue: number?,
	Multiplier: number?,
	SizeScale: number?,
	VisualState: string?,
	TravelScale: number?,
}

export type MachineDefinition = MachineDefinitionSource & {
	Rarity: string,
}

local definitionSources: { [string]: MachineDefinitionSource } = {
	BasicDropper = {
		Id = "BasicDropper",
		DisplayName = "Basic Dropper",
		Category = "Producer",
		Description = "Creates a basic item at a steady rate.",
		Rarity = "Common",
		Rollable = false,
		SpawnInterval = 1,
		OutputValue = 1,
	},
	ValueMultiplier = {
		Id = "ValueMultiplier",
		DisplayName = "Value Multiplier",
		Category = "Processor",
		Description = "Doubles the value of an item.",
		Rollable = true,
		RollChance = 30,
		Behavior = "MultiplyValue",
		Multiplier = 2,
	},
	Seller = {
		Id = "Seller",
		DisplayName = "Seller",
		Category = "Seller",
		Description = "Converts an item into Coins.",
		Rarity = "Infrastructure",
		Rollable = false,
	},
	FastDropper = {
		Id = "FastDropper",
		DisplayName = "Fast Dropper",
		Category = "Producer",
		Description = "Creates lower-value items at a faster rate.",
		Rollable = true,
		RollChance = 5,
		SpawnInterval = 0.5,
		OutputValue = 1,
	},
	HeavyDropper = {
		Id = "HeavyDropper",
		DisplayName = "Heavy Dropper",
		Category = "Producer",
		Description = "Creates valuable items at a slower rate.",
		Rollable = true,
		RollChance = 1.5,
		SpawnInterval = 1.8,
		OutputValue = 4,
	},
	Giantifier = {
		Id = "Giantifier",
		DisplayName = "Giantifier",
		Category = "Processor",
		Description = "Makes the item visibly larger.",
		Rollable = true,
		RollChance = 22,
		Behavior = "ScaleVisual",
		SizeScale = 1.8,
	},
	PaintMachine = {
		Id = "PaintMachine",
		DisplayName = "Paint Machine",
		Category = "Processor",
		Description = "Paints the item for later visual combinations.",
		Rollable = true,
		RollChance = 18,
		Behavior = "SetMaterial",
		VisualState = "Painted",
	},
	CompoundPress = {
		Id = "CompoundPress",
		DisplayName = "Compound Press",
		Category = "Processor",
		Description = "Compresses an item into a higher-value form.",
		Rollable = true,
		RollChance = 4,
		Behavior = "MultiplyValue",
		Multiplier = 3,
	},
	ConveyorBooster = {
		Id = "ConveyorBooster",
		DisplayName = "Conveyor Booster",
		Category = "Processor",
		Description = "Speeds an item through downstream slots.",
		Rollable = true,
		RollChance = 3.5,
		Behavior = "AdjustThroughput",
		TravelScale = 0.5,
	},
	CooldownTuner = {
		Id = "CooldownTuner",
		DisplayName = "Cooldown Tuner",
		Category = "Processor",
		Description = "Provides a smaller, reliable throughput improvement.",
		Rollable = true,
		RollChance = 15,
		Behavior = "AdjustThroughput",
		TravelScale = 0.75,
	},
	Duplicator = {
		Id = "Duplicator",
		DisplayName = "Duplicator",
		Category = "Processor",
		Description = "Creates one bounded additional item.",
		Rollable = true,
		RollChance = 0.7,
		Behavior = "DuplicateItem",
	},
	Goldenizer = {
		Id = "Goldenizer",
		DisplayName = "Goldenizer",
		Category = "Processor",
		Description = "Adds a golden visual state and a bounded value bonus.",
		Rollable = true,
		RollChance = 0.2,
		Behavior = "Goldenize",
		Multiplier = 2,
		VisualState = "Golden",
	},
	LuckyModifier = {
		Id = "LuckyModifier",
		DisplayName = "Lucky Modifier",
		Category = "Processor",
		Description = "Applies a predictable high-or-low value outcome.",
		Rollable = true,
		RollChance = 0.1,
		Behavior = "RandomMultiplier",
	},
}

local definitions: { [string]: MachineDefinition } = {}
for machineId, source in pairs(definitionSources) do
	local rarity = source.Rarity
	if source.Rollable then
		local chance = source.RollChance
		if type(chance) ~= "number" or chance <= 0 or totalRollChance <= 0 then
			error(`Rollable machine {machineId} needs a positive RollChance`)
		end
		rarity = EconomyRules.getRarityFromOdds(EconomyConfig.MachineRollChanceTotal / chance)
	end
	if not rarity then
		error(`Machine {machineId} has no valid rarity`)
	end
	local definition = table.clone(source)
	definition.Rarity = rarity
	definitions[machineId] = definition :: MachineDefinition
end

local MachineDefinitions = {}

function MachineDefinitions.get(machineId: string): MachineDefinition?
	return definitions[machineId]
end

function MachineDefinitions.all(): { [string]: MachineDefinition }
	return definitions
end

function MachineDefinitions.getRollPool(): { MachineDefinition }
	local result = {}
	for _, definition in pairs(definitions) do
		if definition.Rollable then
			table.insert(result, definition)
		end
	end
	return result
end

function MachineDefinitions.validate(): (boolean, string?)
	local producerCount = 0
	local sellerCount = 0
	local totalRollChance = 0
	local seenRollChances: { [number]: string } = {}

	for machineId, definition in pairs(definitions) do
		if definition.Rollable then
			local chance = definition.RollChance
			if type(chance) ~= "number" or chance <= 0 then
				return false, `Rollable machine {machineId} must have a positive RollChance`
			end
			if seenRollChances[chance] then
				return false, `Rollable machines {seenRollChances[chance]} and {machineId} must have different chances`
			end
			seenRollChances[chance] = machineId
			totalRollChance += chance
		elseif definition.RollChance ~= nil then
			return false, `Non-rollable machine {machineId} cannot have a RollChance`
		end
	end

	if math.abs(totalRollChance - EconomyConfig.MachineRollChanceTotal) > 0.000001 then
		return false, `Machine roll chances must total {EconomyConfig.MachineRollChanceTotal}%`
	end

	for machineId, definition in pairs(definitions) do
		if definition.Rollable then
			local chance = definition.RollChance
			if type(chance) ~= "number" then
				return false, `Rollable machine {machineId} must have a numeric RollChance`
			end
			local expectedRarity = EconomyRules.getRarityFromOdds(EconomyConfig.MachineRollChanceTotal / chance)
			if definition.Rarity ~= expectedRarity then
				return false, `Machine {machineId} rarity does not match its chance threshold`
			end
		end
		if definition.Id ~= machineId then
			return false, `Machine ID mismatch for {machineId}`
		end

		if definition.DisplayName == "" or definition.Description == "" then
			return false, `Machine {machineId} is missing readable text`
		end

		if definition.Category == "Producer" then
			producerCount += 1
			if not definition.OutputValue or definition.OutputValue <= 0 then
				return false, `Producer {machineId} must have a positive output value`
			end
		elseif definition.Category == "Processor" then
			local behavior = definition.Behavior
			if behavior == "MultiplyValue" or behavior == "Goldenize" then
				if not definition.Multiplier or definition.Multiplier <= 0 then
					return false, `Processor {machineId} must have a positive multiplier`
				end
			elseif behavior == "ScaleVisual" then
				if not definition.SizeScale or definition.SizeScale <= 0 then
					return false, `Processor {machineId} must have a positive size scale`
				end
			elseif behavior == "SetMaterial" then
				if not definition.VisualState or definition.VisualState == "" then
					return false, `Processor {machineId} must have a visual state`
				end
			elseif behavior == "AdjustThroughput" then
				if not definition.TravelScale or definition.TravelScale <= 0 or definition.TravelScale > 1 then
					return false, `Processor {machineId} must have a bounded travel scale`
				end
			elseif behavior ~= "DuplicateItem" and behavior ~= "RandomMultiplier" then
				return false, `Processor {machineId} has an unsupported behavior`
			end
		elseif definition.Category == "Seller" then
			sellerCount += 1
		else
			return false, `Machine {machineId} has an unsupported category`
		end
	end

	if producerCount == 0 then
		return false, "At least one producer is required"
	end
	if sellerCount == 0 then
		return false, "At least one seller is required"
	end

	return true
end

return MachineDefinitions
