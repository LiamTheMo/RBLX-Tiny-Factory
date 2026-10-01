--!strict

return {
	RollCooldownSeconds = 3,
	MaxInventoryMachines = 200,
	CapacityCosts = { 25, 100 },
	MaxLuckMultiplier = 2,
	MaxSaleValueMultiplier = 10,
	-- First draw: rarity. Second draw: RollWeight among machines of that rarity.
	RarityWeights = { Common = 70, Uncommon = 20, Rare = 8, Epic = 1.8, Legendary = 0.2 },
	UltraRareCutscene = {
		MinimumOddsDenominator = 10000,
		DurationSeconds = 2.4,
	},
	RarityOddsBands = {
		{ Name = "Common", MaxDenominator = 100, LuckBias = 0, Color = { 217, 217, 222 } }, -- #D9D9DE light pastel grey
		{ Name = "Uncommon", MaxDenominator = 500, LuckBias = 0.25, Color = { 191, 232, 197 } }, -- #BFE8C5 pastel light green
		{ Name = "Rare", MaxDenominator = 2500, LuckBias = 0.5, Color = { 184, 216, 240 } }, -- #B8D8F0 pastel baby blue
		{ Name = "Epic", MaxDenominator = 10000, LuckBias = 0.75, Color = { 215, 184, 232 } }, -- #D7B8E8 pastel purple
		{ Name = "Legendary", MaxDenominator = math.huge, LuckBias = 1, Color = { 240, 168, 143 } }, -- #F0A88F pastel orange-red
	},
}
