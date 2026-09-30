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

local SaveSchema = {}
SaveSchema.CurrentVersion = 1

local function defaultData(): { [string]: any }
	return {
		SchemaVersion = SaveSchema.CurrentVersion,
		Coins = 0,
		Inventory = {},
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
		migrated.SchemaVersion = SaveSchema.CurrentVersion
	end
	return migrated
end

function SaveSchema.sanitize(raw: any): { [string]: any }
	local source = SaveSchema.migrate(raw)
	local safe = defaultData()

	if type(source.Coins) == "number" and source.Coins == source.Coins and source.Coins >= 0 then
		safe.Coins = math.min(math.floor(source.Coins * 100 + 0.5) / 100, FactoryConfig.MaxItemValue)
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
				destination[statistic] = math.min(value, 1_000_000)
			end
		end
	end

	sanitizeCounters(source.Statistics, safe.Statistics)
	sanitizeCounters(source.Analytics, safe.Analytics)

	return safe
end

return SaveSchema
