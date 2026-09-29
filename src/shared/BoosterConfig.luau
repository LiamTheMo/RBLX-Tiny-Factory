--!strict

return {
	WorldFolderName = "TinyFactoryBoosters",
	SpawnIntervalSeconds = 12,
	MaxActiveDropsPerFactory = 3,
	MaxActiveDropsWorldwide = 24,
	DespawnAfterSeconds = 45,
	MaxLuckDurationSeconds = 120,
	SpawnBounds = { MinX = 1.5, MaxX = 26.5, MinZ = -2.5, MaxZ = 2.5, Height = 1.1 },
	Definitions = {
		{ Id = "Coin", DisplayName = "+5 Coins", SpawnWeight = 70, Color = { 255, 218, 76 }, Effect = { Kind = "Coins", Amount = 5 } },
		{ Id = "Luck", DisplayName = "Luck x2 · 30s", SpawnWeight = 30, Color = { 207, 176, 240 }, Effect = { Kind = "Luck", Multiplier = 2, DurationSeconds = 30 } },
	},
}
