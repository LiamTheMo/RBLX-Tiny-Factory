--!strict

local function requireSibling(name: string): any
	if script ~= nil then
		return require(script.Parent[name])
	end
	return require("./" .. name)
end

local FactoryConfig = requireSibling("FactoryConfig")
local FactoryLayout = requireSibling("FactoryLayout")
local MachineDefinitions = requireSibling("MachineDefinitions")
local PlacementRules = requireSibling("PlacementRules")
local BoosterRules = requireSibling("BoosterRules")

local SaveSchema = {}
SaveSchema.CurrentVersion = 4

local function defaultData(): { [string]: any }
	return {
		SchemaVersion = SaveSchema.CurrentVersion,
		Coins = 0,
		Inventory = {},
		BoosterInventory = {},
		Layout = FactoryLayout.copy(FactoryLayout.Default),
		Capacity = 1,
		RollCount = 0,
		Statistics = {},
		Analytics = {},
	}
end

function SaveSchema.default(): { [string]: any }
	return defaultData()
end

function SaveSchema.migrate(raw: any): { [string]: any }
	if type(raw) ~= "table" then
		return defaultData()
	end
	local version = if type(raw.SchemaVersion) == "number" then raw.SchemaVersion else 0
	if version > SaveSchema.CurrentVersion then
		return defaultData()
	end
	local migrated = {}
	for key, value in pairs(raw) do
		migrated[key] = value
	end
	if version == 0 then
		version = 1
		migrated.SchemaVersion = version
	end
	if version == 1 then
		local legacyLayout = migrated.Layout
		if type(legacyLayout) == "table" and legacyLayout[5] == "Seller" then
			local compactLayout = table.clone(legacyLayout)
			local overflowMachineId = compactLayout[4]
			if type(overflowMachineId) == "string" then
				local definition = MachineDefinitions.get(overflowMachineId)
				if definition and definition.Rollable then
					local inventory = if type(migrated.Inventory) == "table" then table.clone(migrated.Inventory) else {}
					local existing = inventory[overflowMachineId]
					inventory[overflowMachineId] = (if type(existing) == "number" and existing % 1 == 0 and existing > 0 then existing else 0) + 1
					migrated.Inventory = inventory
				end
			end
			compactLayout[4] = "Seller"
			compactLayout[5] = nil
			migrated.Layout = compactLayout
		end
		if type(migrated.Capacity) == "number" then
			migrated.Capacity = math.min(migrated.Capacity, FactoryConfig.MaxFactoryCapacity)
		end
		migrated.SchemaVersion = 2
		version = 2
	end
	if version == 2 then
		local legacyLayout = migrated.Layout
		if type(legacyLayout) == "table" then
			local sellerSlot: number? = nil
			for slotIndex = 1, FactoryLayout.SlotCount do
				local definition = MachineDefinitions.get(legacyLayout[slotIndex])
				if definition and definition.Category == "Seller" then
					sellerSlot = slotIndex
					break
				end
			end
			if sellerSlot and sellerSlot ~= FactoryLayout.SellerSlotIndex then
				local updatedLayout = table.clone(legacyLayout)
				local displaced = updatedLayout[FactoryLayout.SellerSlotIndex]
				local displacedDefinition = MachineDefinitions.get(displaced)
				if displacedDefinition and displacedDefinition.Rollable then
					local inventory = if type(migrated.Inventory) == "table" then table.clone(migrated.Inventory) else {}
					local existing = inventory[displaced]
					inventory[displaced] = (if type(existing) == "number" and existing % 1 == 0 and existing > 0 then existing else 0) + 1
					migrated.Inventory = inventory
				end
				updatedLayout[sellerSlot] = nil
				updatedLayout[FactoryLayout.SellerSlotIndex] = legacyLayout[sellerSlot]
				migrated.Layout = updatedLayout
			end
		end
		migrated.BoosterInventory = migrated.BoosterInventory or {}
		migrated.SchemaVersion = 3
		version = 3
	end
	if version == 3 then
		local legacyLayout = migrated.Layout
		if type(legacyLayout) == "table" then
			local legacySellerSlot: number? = nil
			for slotIndex = 1, FactoryLayout.SellerSlotIndex - 1 do
				local definition = MachineDefinitions.get(legacyLayout[slotIndex])
				if definition and definition.Category == "Seller" then
					legacySellerSlot = slotIndex
					break
				end
			end
			if legacySellerSlot then
				local updatedLayout = table.clone(legacyLayout)
				updatedLayout[FactoryLayout.SellerSlotIndex] = legacyLayout[legacySellerSlot]
				updatedLayout[legacySellerSlot] = nil
				migrated.Layout = updatedLayout
			end
		end
		if type(migrated.Capacity) == "number" then
			migrated.Capacity = math.clamp(migrated.Capacity, 1, FactoryConfig.MaxFactoryCapacity)
		end
		migrated.SchemaVersion = 4
	end
	return migrated
end

function SaveSchema.sanitize(raw: any): { [string]: any }
	local source = SaveSchema.migrate(raw)
	local safe = defaultData()

	if type(source.Coins) == "number" and source.Coins == source.Coins and source.Coins >= 0 then
		safe.Coins = math.min(math.floor(source.Coins), FactoryConfig.MaxCoins)
	end
	if type(source.Capacity) == "number" and source.Capacity % 1 == 0 then
		safe.Capacity = math.clamp(source.Capacity, 1, FactoryConfig.MaxFactoryCapacity)
	end
	if type(source.RollCount) == "number" and source.RollCount % 1 == 0 and source.RollCount >= 0 then
		safe.RollCount = math.min(source.RollCount, 100_000)
	end

	if type(source.Inventory) == "table" then
		for machineId, quantity in pairs(source.Inventory) do
			local definition = if type(machineId) == "string" then MachineDefinitions.get(machineId) else nil
			if definition and definition.Rollable and type(quantity) == "number" and quantity % 1 == 0 and quantity > 0 then
				safe.Inventory[machineId] = math.min(quantity, 1_000)
			end
		end
	end

	safe.BoosterInventory = BoosterRules.sanitizeInventory(source.BoosterInventory)

	if type(source.Layout) == "table" then
		local candidate = {}
		for slotIndex = 1, FactoryLayout.SlotCount do
			local machineId = source.Layout[slotIndex]
			candidate[slotIndex] = if type(machineId) == "string" and machineId ~= "" then machineId else nil
		end
		local valid = PlacementRules.validateLayout(candidate, safe.Capacity)
		if valid then
			safe.Layout = FactoryLayout.copy(candidate)
		end
	end

	local function sanitizeCounters(sourceCounters: any, destination: { [string]: number })
		if type(sourceCounters) ~= "table" then
			return
		end
		for statistic, value in pairs(sourceCounters) do
			if type(statistic) == "string" and statistic:match("^[%a_][%w_]*$") and #statistic <= 48 and type(value) == "number" and value >= 0 and value % 1 == 0 then
				destination[statistic] = math.min(value, if statistic == "TotalValueSold" then FactoryConfig.MaxCoins else 1_000_000)
			end
		end
	end

	sanitizeCounters(source.Statistics, safe.Statistics)
	sanitizeCounters(source.Analytics, safe.Analytics)

	return safe
end

return SaveSchema
