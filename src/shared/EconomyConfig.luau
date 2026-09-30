--!strict

return {
	RollCooldownSeconds = 3,
	MaxInventoryMachines = 200,
	CapacityCosts = { 25, 100 },
	-- Stage 1: select a rarity. Stage 2 uses each matching machine's RollWeight.
	-- Since these values sum to 100, they also read as rarity percentages.
	RarityWeights = {
		Common = 70,
		Uncommon = 20,
		Rare = 8,
		Epic = 1.8,
		Legendary = 0.2,
	},
}
