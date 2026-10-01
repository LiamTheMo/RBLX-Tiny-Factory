--!strict

local CubeTypeDefinitions
local function requireSibling(name: string): any
	if script ~= nil then return require(script.Parent[name]) end
	return require("./" .. name)
end
CubeTypeDefinitions = requireSibling("CubeTypeDefinitions")

export type ValueModifierLayer = { AdditiveBonus: number?, Multiplier: number? }

export type MachineCategory = "Producer" | "Processor" | "Seller"

export type MachineDefinition = {
	Id: string,
	DisplayName: string,
	Category: MachineCategory,
	Description: string,
	Rarity: string,
	Rollable: boolean,
	RollWeight: number?,
	OutputType: string?,
	TypeModifiers: ValueModifierLayer?,
	SaleModifiers: ValueModifierLayer?,
	VisualStyle: string?,
	Behavior: string?,
	SpawnInterval: number?,
	OutputValue: number?,
	CubeType: string?,
	Multiplier: number?,
	TypeFilter: string?,
	SizeScale: number?,
	VisualState: string?,
	TravelScale: number?,
	PayoutMultiplier: number?,
	SaleIntervalSeconds: number?,
	MinimumValue: number?,
	BonusChance: number?,
	BonusEvery: number?,
	BonusMultiplier: number?,
	RequiredCubeRarity: string?,
}

local function producer(id: string, name: string, rarity: string, weight: number, description: string, interval: number, value: number, cubeType: string): MachineDefinition
	local typeDefinition = CubeTypeDefinitions.get(cubeType)
	return {
		Id = id, DisplayName = name, Category = "Producer", Description = description,
		Rarity = rarity, Rollable = true, RollWeight = weight, SpawnInterval = interval,
		OutputValue = value, CubeType = cubeType, OutputType = cubeType,
		TypeModifiers = { AdditiveBonus = 0, Multiplier = typeDefinition and typeDefinition.ValueMultiplier or 1 },
		VisualStyle = "Dropper",
	}
end

local function typeUpgrader(id: string, name: string, rarity: string, weight: number, cubeType: string, multiplier: number, description: string): MachineDefinition
	return { Id = id, DisplayName = name, Category = "Processor", Description = description, Rarity = rarity, Rollable = true, RollWeight = weight, Behavior = "TypeMultiplier", TypeFilter = cubeType, Multiplier = multiplier, VisualStyle = "Processor" }
end

local definitions: { [string]: MachineDefinition } = {
	-- Fixed starter infrastructure. Players can roll alternate droppers and sellers.
	BasicDropper = { Id = "BasicDropper", DisplayName = "Basic Dropper", Category = "Producer", Description = "Creates standard cubes at a steady rate.", Rarity = "Common", Rollable = false, SpawnInterval = 1, OutputValue = 1, CubeType = "Standard", OutputType = "Standard", TypeModifiers = { AdditiveBonus = 0, Multiplier = 1 }, VisualStyle = "Dropper" },
	Seller = { Id = "Seller", DisplayName = "Pocket Cashier", Category = "Seller", Description = "Pays the cube's full value reliably.", Rarity = "Common", Rollable = true, RollWeight = 2, Behavior = "Payout", PayoutMultiplier = 1, SaleIntervalSeconds = 1, SaleModifiers = { AdditiveBonus = 0, Multiplier = 1 }, VisualStyle = "Seller" },

	-- Rollable producers. Each cube type has its own base value multiplier.
	IslandStarter = producer("IslandStarter", "Island Starter", "Common", 8, "A dependable starter line for standard cubes.", 1.5, 5, "Standard"),
	Raincatcher = producer("Raincatcher", "Raincatcher", "Uncommon", 5, "Makes Wet cubes with a water-powered drop cycle.", 1.8, 5, "Wet"),
	BreezeBell = producer("BreezeBell", "Breeze Bell", "Uncommon", 5, "Makes light Air cubes quickly.", 1.25, 5, "Air"),
	MossyMaker = producer("MossyMaker", "Mossy Maker", "Uncommon", 4, "Grows Nature cubes along a leafy production line.", 2, 5, "Nature"),
	EarthPress = producer("EarthPress", "Pebble Press", "Uncommon", 3, "Forms sturdy Earth cubes from island stone.", 2.1, 5, "Earth"),
	EmberPress = producer("EmberPress", "Ember Press", "Rare", 4, "Makes valuable Fire cubes in a warm, safe furnace.", 2.3, 5, "Fire"),
	FrostPopper = producer("FrostPopper", "Frost Popper", "Rare", 3, "Makes cool Ice cubes from its frosty chamber.", 2.2, 5, "Ice"),
	MetalMolder = producer("MetalMolder", "Metal Molder", "Rare", 3, "Casts durable Metal cubes.", 2.4, 5, "Metal"),
	SparkSprout = producer("SparkSprout", "Spark Sprout", "Rare", 3, "Makes energized Lightning cubes.", 2.5, 5, "Lightning"),
	GlowGarden = producer("GlowGarden", "Glow Garden", "Epic", 3, "Grows bright Light cubes.", 2.8, 5, "Light"),
	ShadowSpinner = producer("ShadowSpinner", "Shadow Spinner", "Epic", 2, "Makes mysterious Shadow cubes.", 3, 5, "Shadow"),
	TimeTicker = producer("TimeTicker", "Time Ticker", "Epic", 2, "Makes valuable Time cubes on a slower clockwork cycle.", 3.2, 5, "Time"),
	CrystalBloom = producer("CrystalBloom", "Crystal Bloom", "Epic", 2, "Grows faceted Crystal cubes.", 3.3, 5, "Crystal"),
	TideTurner = producer("TideTurner", "Tide Turner", "Epic", 2, "A waterwheel dropper that makes high-value Wet cubes.", 1.6, 7, "Wet"),
	PrismBloom = producer("PrismBloom", "Prism Bloom", "Legendary", 1, "Makes rare Rainbow cubes with a powerful base multiplier.", 3.8, 5, "Rainbow"),
	FastDropper = { Id = "FastDropper", DisplayName = "Fast Dropper", Category = "Producer", Description = "Creates standard cubes at a faster rate.", Rarity = "Uncommon", Rollable = true, RollWeight = 3, SpawnInterval = 0.8, OutputValue = 5, CubeType = "Standard" },
	HeavyDropper = { Id = "HeavyDropper", DisplayName = "Heavy Dropper", Category = "Producer", Description = "Creates standard cubes slowly for a higher base value.", Rarity = "Rare", Rollable = true, RollWeight = 2, SpawnInterval = 2.4, OutputValue = 8, CubeType = "Standard" },

	-- Rollable upgraders. Type-filtered bonuses stack with the cube type multiplier.
	PolishedRoller = { Id = "PolishedRoller", DisplayName = "Polished Roller", Category = "Processor", Description = "Adds a small value bonus to every cube.", Rarity = "Common", Rollable = true, RollWeight = 5, Behavior = "MultiplyValue", Multiplier = 1.1 },
	RainRinse = typeUpgrader("RainRinse", "Rain Rinse", "Uncommon", 3, "Wet", 1.2, "Adds value to Wet cubes only."),
	BreezyBumper = typeUpgrader("BreezyBumper", "Breezy Bumper", "Uncommon", 3, "Air", 1.2, "Adds value to Air cubes only."),
	MossMixer = typeUpgrader("MossMixer", "Moss Mixer", "Uncommon", 3, "Nature", 1.25, "Adds value to Nature cubes only."),
	EmberCoater = typeUpgrader("EmberCoater", "Ember Coater", "Rare", 3, "Fire", 1.35, "Adds value to Fire cubes only."),
	StaticStamper = typeUpgrader("StaticStamper", "Static Stamper", "Rare", 3, "Lightning", 1.4, "Adds value to Lightning cubes only."),
	FrostFramer = typeUpgrader("FrostFramer", "Frost Framer", "Rare", 2, "Ice", 1.35, "Adds value to Ice cubes only."),
	LuckyLantern = { Id = "LuckyLantern", DisplayName = "Lucky Lantern", Category = "Processor", Description = "One in ten cubes receives double value.", Rarity = "Epic", Rollable = true, RollWeight = 2, Behavior = "RandomMultiplier", BonusChance = 0.1, BonusMultiplier = 2 },
	TimeTwister = { Id = "TimeTwister", DisplayName = "Time Twister", Category = "Processor", Description = "Adds a strong bonus to Time cubes.", Rarity = "Epic", Rollable = true, RollWeight = 2, Behavior = "TypeMultiplier", TypeFilter = "Time", Multiplier = 1.5 },
	RainbowRefractor = { Id = "RainbowRefractor", DisplayName = "Rainbow Refractor", Category = "Processor", Description = "Further enhances Rainbow cubes.", Rarity = "Legendary", Rollable = true, RollWeight = 1, Behavior = "TypeMultiplier", TypeFilter = "Rainbow", Multiplier = 1.75 },
	-- Existing physical, throughput, and item-count behaviors remain rollable.
	ValueMultiplier = { Id = "ValueMultiplier", DisplayName = "Value Multiplier", Category = "Processor", Description = "Doubles an item's value.", Rarity = "Common", Rollable = true, RollWeight = 3, Behavior = "MultiplyValue", Multiplier = 2 },
	Giantifier = { Id = "Giantifier", DisplayName = "Giantifier", Category = "Processor", Description = "Makes the item visibly larger.", Rarity = "Common", Rollable = true, RollWeight = 2, Behavior = "ScaleVisual", SizeScale = 1.8 },
	PaintMachine = { Id = "PaintMachine", DisplayName = "Paint Machine", Category = "Processor", Description = "Paints the item for later visual combinations.", Rarity = "Common", Rollable = true, RollWeight = 2, Behavior = "SetMaterial", VisualState = "Painted" },
	CompoundPress = { Id = "CompoundPress", DisplayName = "Compound Press", Category = "Processor", Description = "Compresses an item into a higher-value form.", Rarity = "Uncommon", Rollable = true, RollWeight = 2, Behavior = "MultiplyValue", Multiplier = 1.5 },
	ConveyorBooster = { Id = "ConveyorBooster", DisplayName = "Conveyor Booster", Category = "Processor", Description = "Speeds an item through downstream slots.", Rarity = "Uncommon", Rollable = true, RollWeight = 2, Behavior = "AdjustThroughput", TravelScale = 0.5 },
	CooldownTuner = { Id = "CooldownTuner", DisplayName = "Cooldown Tuner", Category = "Processor", Description = "Provides a smaller, reliable throughput improvement.", Rarity = "Common", Rollable = true, RollWeight = 2, Behavior = "AdjustThroughput", TravelScale = 0.75 },
	Duplicator = { Id = "Duplicator", DisplayName = "Duplicator", Category = "Processor", Description = "Creates one bounded additional item.", Rarity = "Epic", Rollable = true, RollWeight = 1, Behavior = "DuplicateItem" },
	Goldenizer = { Id = "Goldenizer", DisplayName = "Goldenizer", Category = "Processor", Description = "Adds a golden visual state and bounded value bonus.", Rarity = "Epic", Rollable = true, RollWeight = 1, Behavior = "Goldenize", Multiplier = 2, VisualState = "Golden" },
	LuckyModifier = { Id = "LuckyModifier", DisplayName = "Lucky Modifier", Category = "Processor", Description = "Alternates between bounded high and low value outcomes.", Rarity = "Legendary", Rollable = true, RollWeight = 1, Behavior = "RandomMultiplier" },

	-- Alternate sellers are rolls and can be installed in the terminal seller slot.
	QuickCountCounter = { Id = "QuickCountCounter", DisplayName = "Quick-Count Counter", Category = "Seller", Description = "Processes each sale in 0.5 seconds with a slightly lower payout.", Rarity = "Uncommon", Rollable = true, RollWeight = 4, Behavior = "Payout", PayoutMultiplier = 0.95, SaleIntervalSeconds = 0.5 },
	PremiumAppraiser = { Id = "PremiumAppraiser", DisplayName = "Premium Appraiser", Category = "Seller", Description = "Pays 15% more for cubes worth at least 25.", Rarity = "Rare", Rollable = true, RollWeight = 3, Behavior = "ConditionalPayout", MinimumValue = 25, PayoutMultiplier = 1.15, SaleIntervalSeconds = 1.25 },
	TypeCollector = { Id = "TypeCollector", DisplayName = "Type Collector", Category = "Seller", Description = "Pays 30% more for Wet cubes.", Rarity = "Rare", Rollable = true, RollWeight = 2, Behavior = "TypePayout", TypeFilter = "Wet", PayoutMultiplier = 1.3, SaleIntervalSeconds = 1.25 },
	LuckyTill = { Id = "LuckyTill", DisplayName = "Lucky Till", Category = "Seller", Description = "One in eight sales receives a 50% bonus.", Rarity = "Epic", Rollable = true, RollWeight = 2, Behavior = "ChancePayout", BonusChance = 0.125, BonusMultiplier = 1.5, SaleIntervalSeconds = 1.5 },
	StreakRegister = { Id = "StreakRegister", DisplayName = "Streak Register", Category = "Seller", Description = "Every tenth sale pays double.", Rarity = "Epic", Rollable = true, RollWeight = 2, Behavior = "StreakPayout", BonusEvery = 10, BonusMultiplier = 2, SaleIntervalSeconds = 1.5 },
	RainbowExchange = { Id = "RainbowExchange", DisplayName = "Rainbow Exchange", Category = "Seller", Description = "Pays 50% more for Epic and Legendary cube types.", Rarity = "Legendary", Rollable = true, RollWeight = 1, Behavior = "RarityPayout", RequiredCubeRarity = "Epic", PayoutMultiplier = 1.5, SaleIntervalSeconds = 2 },
}

local MachineDefinitions = {}

function MachineDefinitions.get(machineId: string): MachineDefinition?
	return definitions[machineId]
end

function MachineDefinitions.all(): { [string]: MachineDefinition }
	return definitions
end

function MachineDefinitions.getRollPool(rarity: string?): { MachineDefinition }
	local result = {}
	for _, definition in pairs(definitions) do
		if definition.Rollable and (rarity == nil or definition.Rarity == rarity) then
			table.insert(result, definition)
		end
	end
	return result
end

function MachineDefinitions.validate(): (boolean, string?)
	local producerCount = 0
	local sellerCount = 0
	local rarities = { Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true }
	for machineId, definition in pairs(definitions) do
		definition.VisualStyle = definition.VisualStyle or (if definition.Category == "Producer" then "Dropper" elseif definition.Category == "Seller" then "Seller" else "Processor")
		if definition.Category == "Producer" then
			local cubeType = definition.CubeType or "Standard"
			local typeDefinition = CubeTypeDefinitions.get(cubeType)
			definition.OutputType = cubeType
			definition.TypeModifiers = definition.TypeModifiers or { AdditiveBonus = 0, Multiplier = typeDefinition and typeDefinition.ValueMultiplier or 1 }
		elseif definition.Category == "Seller" then
			definition.SaleModifiers = definition.SaleModifiers or { AdditiveBonus = 0, Multiplier = 1 }
		end
		if definition.Id ~= machineId then
			return false, `Machine ID mismatch for {machineId}`
		end
		if definition.DisplayName == "" or definition.Description == "" then
			return false, `Machine {machineId} is missing readable text`
		end
		if definition.Rollable and (not rarities[definition.Rarity] or not definition.RollWeight or definition.RollWeight ~= definition.RollWeight or definition.RollWeight <= 0 or definition.RollWeight == math.huge) then
			return false, `Rollable machine {machineId} needs a supported rarity and positive inner weight`
		end
		if definition.Category == "Producer" then
			producerCount += 1
			if not definition.OutputValue or definition.OutputValue <= 0 or not definition.SpawnInterval or definition.SpawnInterval <= 0 then
				return false, `Producer {machineId} must have positive value and spawn interval`
			end
				if not definition.CubeType or not CubeTypeDefinitions.get(definition.CubeType) then
					return false, `Producer {machineId} must declare a cube type`
				end
		elseif definition.Category == "Processor" then
			local behavior = definition.Behavior
				if behavior == "MultiplyValue" or behavior == "Goldenize" or behavior == "TypeMultiplier" then
				if not definition.Multiplier or definition.Multiplier <= 0 then
					return false, `Processor {machineId} must have a positive multiplier`
				end
				if behavior == "TypeMultiplier" and (not definition.TypeFilter or not CubeTypeDefinitions.get(definition.TypeFilter)) then
					return false, `Processor {machineId} must declare a valid supported cube type`
				end
			elseif behavior == "ScaleVisual" then
				if not definition.SizeScale or definition.SizeScale <= 0 then return false, `Processor {machineId} must have a positive size scale` end
			elseif behavior == "SetMaterial" then
				if not definition.VisualState or definition.VisualState == "" then return false, `Processor {machineId} must have a visual state` end
			elseif behavior == "AdjustThroughput" then
				if not definition.TravelScale or definition.TravelScale <= 0 or definition.TravelScale > 1 then return false, `Processor {machineId} must have a bounded travel scale` end
			elseif behavior == "RandomMultiplier" then
				if definition.BonusChance ~= nil and (definition.BonusChance < 0 or definition.BonusChance > 1) then return false, `Processor {machineId} has an invalid bonus chance` end
			elseif behavior ~= "DuplicateItem" then
				return false, `Processor {machineId} has an unsupported behavior`
			end
		elseif definition.Category == "Seller" then
			sellerCount += 1
			local sellerBehaviors = { Payout = true, ConditionalPayout = true, TypePayout = true, ChancePayout = true, StreakPayout = true, RarityPayout = true }
			if not sellerBehaviors[definition.Behavior or "Payout"] then return false, `Seller {machineId} has an unsupported behavior` end
			if definition.SaleIntervalSeconds ~= nil and (definition.SaleIntervalSeconds < 0 or definition.SaleIntervalSeconds > 10) then return false, `Seller {machineId} has an invalid sale interval` end
			if definition.PayoutMultiplier ~= nil and (definition.PayoutMultiplier <= 0 or definition.PayoutMultiplier > 10) then return false, `Seller {machineId} has an invalid payout multiplier` end
			if definition.Behavior == "ConditionalPayout" and (not definition.MinimumValue or definition.MinimumValue <= 0) then return false, `Seller {machineId} needs a positive minimum value` end
			if definition.Behavior == "TypePayout" and (not definition.TypeFilter or not CubeTypeDefinitions.get(definition.TypeFilter)) then return false, `Seller {machineId} needs a valid cube type filter` end
			if definition.Behavior == "ChancePayout" and (not definition.BonusChance or definition.BonusChance < 0 or definition.BonusChance > 1) then return false, `Seller {machineId} needs a bounded bonus chance` end
			if definition.Behavior == "StreakPayout" and (not definition.BonusEvery or definition.BonusEvery < 1 or definition.BonusEvery % 1 ~= 0) then return false, `Seller {machineId} needs a positive sale interval` end
		elseif definition.Category ~= "Processor" then
			return false, `Machine {machineId} has an unsupported category`
		end
	end
	if producerCount == 0 then return false, "At least one producer is required" end
	if sellerCount == 0 then return false, "At least one seller is required" end
	return true
end

return MachineDefinitions
