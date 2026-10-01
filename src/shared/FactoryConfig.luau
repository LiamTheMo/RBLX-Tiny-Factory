--!strict

-- Phase 1 keeps the simulation intentionally small and bounded. These values
-- are shared by the server and the pure simulation tests; economy tuning should
-- remain data-driven as later phases add configuration services.
local FactoryConfig = {
	BuildVersion = "v2.00",
	SchemaVersion = 4,
	MaxActiveItems = 24,
	MaxItemValue = 1_000_000,
	MaxCoins = 9_007_199_254_740_991, -- largest exactly representable integer
	MaxItemModifierLabels = 8,
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 1.15,
	MaxCatchUpSpawnsPerStep = 256,
	MaxFactoryCapacity = 3,
	DefaultRoute = { "BasicDropper", "ValueMultiplier", "Seller" },
}

return FactoryConfig
