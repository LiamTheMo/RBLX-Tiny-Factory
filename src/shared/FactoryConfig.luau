--!strict

-- Phase 1 keeps the simulation intentionally small and bounded. These values
-- are shared by the server and the pure simulation tests; economy tuning should
-- remain data-driven as later phases add configuration services.
local FactoryConfig = {
	BuildVersion = "v1.00",
	SchemaVersion = 2,
	MaxActiveItems = 24,
	MaxItemValue = 1_000_000,
	SpawnIntervalSeconds = 1,
	TravelTimePerSlotSeconds = 0.25,
	MaxCatchUpSpawnsPerStep = 256,
	MaxFactoryCapacity = 2,
	DefaultRoute = { "BasicDropper", "ValueMultiplier", "Seller" },
}

return FactoryConfig
