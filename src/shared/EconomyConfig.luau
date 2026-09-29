--!strict

return {
	RollCooldownSeconds = 3,
	MaxInventoryMachines = 200,
	CapacityCosts = { 25, 100 },
	MachineRollChanceTotal = 100,
	RarityOddsBands = {
		{ Name = "Common", MaxDenominator = 100, Color = { 225, 225, 225 } },
		{ Name = "Uncommon", MaxDenominator = 500, Color = { 110, 239, 151 } },
		{ Name = "Rare", MaxDenominator = 2500, Color = { 99, 178, 255 } },
		{ Name = "Epic", MaxDenominator = 10000, Color = { 195, 116, 255 } },
		{ Name = "Legendary", MaxDenominator = math.huge, Color = { 255, 202, 70 } },
	},
}
