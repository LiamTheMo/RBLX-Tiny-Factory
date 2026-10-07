--!strict
-- Run with Luau from the repository root to regenerate the catalog document.
local Definitions = require("../src/shared/MachineDefinitions")
local Rules = require("../src/shared/EconomyRules")
assert(Definitions.validate())
local pool = Definitions.getRollPool()
print("# MVP Machine Catalog\n\nGenerated from shared definitions with `luau scripts/catalog_report.luau`. Base odds exclude Luck. Rarity is selected first, then the item weight within the entire rarity pool, including upgraders. Stats are starting playtest values; models remain provisional.\n")
for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
	print(`## {rarity}\n`)
	print("| Machine / stable ID | Category | Weight | Base odds (1/x) | Stats and behavior |")
	print("| --- | --- | ---: | ---: | --- |")
	local entries = Definitions.getRollPool(rarity)
	table.sort(entries, function(a, b)
		return if a.Category == b.Category then a.Id < b.Id else a.Category < b.Category
	end)
	for _, definition in ipairs(entries) do
		local stats = definition.Description
		if definition.Category == "Producer" then
			stats = `{definition.CubeType}; {definition.OutputValue} base Coins; every {definition.SpawnInterval}s; type multiplier x{definition.TypeModifiers.Multiplier}`
		elseif definition.Category == "Seller" then
			stats ..= ` Sale cooldown: {definition.SaleIntervalSeconds or 0}s.`
		end
		local odds = string.format("%.2f", assert(Rules.getMachineOddsDenominator(definition.Id, pool)))
		print(`| {definition.DisplayName} / {definition.Id} | {definition.Category} | {definition.RollWeight} | {odds} | {stats} |`)
	end
	print("")
end
