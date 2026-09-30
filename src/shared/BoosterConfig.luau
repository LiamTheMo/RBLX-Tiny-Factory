--!strict

return {
	WorldFolderName = "TinyFactoryBoosters",
	SpawnIntervalSeconds = 12,
	MaxActiveDropsPerFactory = 3,
	MaxActiveDropsWorldwide = 24,
	DespawnAfterSeconds = 45,
	MaxLuckDurationSeconds = 120,
	MaxSaleValueDurationSeconds = 120,
	MaxStoredPerType = 99,
	SpawnBounds = { MinX = 1.5, MaxX = 26.5, MinZ = -2.5, MaxZ = 2.5 },
	LandRaycast = {
		StartHeight = 120,
		Distance = 240,
		PositionAttempts = 8,
		MinimumGroundNormalY = 0.7,
	},
	Fall = {
		DropHeight = 8,
		DurationSeconds = 0.75,
		StartingSize = 0.25,
		LandedSize = 1.3,
		LandingHeight = 0.75,
	},
	Definitions = {
		{ Id = "Coin", DisplayName = "Coins x2.00 · 30s", SpawnWeight = 70, Color = { 255, 218, 76 }, Effect = { Kind = "SaleValue", Multiplier = 2, DurationSeconds = 30 } },
		{ Id = "Luck", DisplayName = "Luck x2.00 · 30s", SpawnWeight = 30, Color = { 207, 176, 240 }, Effect = { Kind = "Luck", Multiplier = 2, DurationSeconds = 30 } },
	},
}
