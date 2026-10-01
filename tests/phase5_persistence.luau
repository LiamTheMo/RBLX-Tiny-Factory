local SaveSchema = require("../src/shared/SaveSchema")
local FactoryConfig = require("../src/shared/FactoryConfig")
local FactoryLayout = require("../src/shared/FactoryLayout")
local PersistenceSession = require("../src/server/Services/PersistenceSession")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local defaultData = SaveSchema.default()
expect(defaultData.SchemaVersion == SaveSchema.CurrentVersion, "default data must use the current schema")
expect(defaultData.Capacity == 1, "default capacity should be one")
expect(type(defaultData.BoosterInventory) == "table", "default booster inventory must be present")
expect(type(defaultData.Analytics) == "table", "default data must include bounded analytics storage")
expect(defaultData.Layout[1] == FactoryLayout.Default[1], "default producer must be persisted")
expect(defaultData.Layout[5] == FactoryLayout.Default[5], "default seller must be persisted in the seller bay")

local safe = SaveSchema.sanitize({
	Coins = 9_999_999_999,
	Capacity = 99,
	RollCount = 4,
	BoosterInventory = { Coin = 200, Luck = 2, Unknown = 10, Negative = -1 },
	Inventory = {
		FastDropper = 5,
		BasicDropper = 100,
		NotAMachine = 100,
	},
	Layout = { "BasicDropper", "Giantifier", nil, nil, "Seller" },
	Statistics = {
		ProducedItems = 12,
		Negative = -1,
		TooLarge = 9_999_999_999,
	},
	Analytics = {
		MachinePlaced = 3,
		["invalid-event"] = 5,
		TooLarge = 9_999_999_999,
	},
})
expect(safe.Coins == 9_999_999_999, "valid wallets above the cube cap must survive sanitization")
expect(safe.Capacity == FactoryConfig.MaxFactoryCapacity, "capacity must be capped during sanitization")
expect(safe.RollCount == 4, "valid roll count should survive sanitization")
expect(safe.BoosterInventory.Coin == 99 and safe.BoosterInventory.Luck == 2 and safe.BoosterInventory.Unknown == nil, "booster counts should be bounded and known")
expect(safe.Inventory.FastDropper == 5, "valid rollable inventory should survive sanitization")
expect(safe.Inventory.BasicDropper == nil, "non-rollable machines must not enter inventory")
expect(safe.Inventory.NotAMachine == nil, "unknown machines must not enter inventory")
expect(safe.Layout[2] == "Giantifier", "valid processor layout should survive sanitization")
expect(safe.Statistics.ProducedItems == 12, "valid statistics should survive sanitization")
expect(safe.Statistics.Negative == nil, "negative statistics must be removed")

local fakeStore = { value = nil, fail = false }
function fakeStore:UpdateAsync(_key: string, transform: (any) -> any)
	if self.fail then error("injected failure") end
	local replacement = transform(self.value)
	if replacement ~= nil then self.value = replacement end
	return replacement
end
local acquired, acquiredData = PersistenceSession.acquire(fakeStore, "user", "session-a", 100, 300, SaveSchema.sanitize)
expect(acquired and acquiredData.Coins == SaveSchema.default().Coins, "session acquisition should initialize sanitized data")
local secondAcquire, _, lockError = PersistenceSession.acquire(fakeStore, "user", "session-b", 120, 300, SaveSchema.sanitize)
expect(not secondAcquire and lockError == "locked", "a live session must prevent a second owner")
local staleAcquire = PersistenceSession.acquire(fakeStore, "user", "session-b", 500, 300, SaveSchema.sanitize)
expect(staleAcquire, "expired session lock should be recoverable")
local conflictSave, conflictError = PersistenceSession.save(fakeStore, "user", "session-a", safe, false, 501)
expect(not conflictSave and conflictError == "conflict", "a previous owner must not overwrite the new session")
fakeStore.fail = true
local failedSave, saveError = PersistenceSession.save(fakeStore, "user", "session-b", safe, false, 502)
expect(not failedSave and saveError == "store", "store failures should surface to the caller")
fakeStore.fail = false
local saved = PersistenceSession.save(fakeStore, "user", "session-b", safe, false, 503)
expect(saved and fakeStore.value.Data.Coins == safe.Coins, "current owner should persist sanitized state")
fakeStore.value._SessionId = nil
local ownerlessSave, ownerlessError = PersistenceSession.save(fakeStore, "user", "session-b", safe, false, 504)
expect(not ownerlessSave and ownerlessError == "conflict", "an unowned record must not be overwritten by a stale session")
expect(safe.Statistics.TooLarge == 1_000_000, "statistics must be capped")
expect(safe.Analytics.MachinePlaced == 3, "valid analytics counters should survive sanitization")
expect(safe.Analytics["invalid-event"] == nil, "analytics event names must be schema-safe")
expect(safe.Analytics.TooLarge == 1_000_000, "analytics counters must be capped")

local invalidLayout = SaveSchema.sanitize({
	Layout = { "ValueMultiplier", nil, nil, nil, "Seller" },
})
expect(invalidLayout.Layout[1] == FactoryLayout.Default[1], "invalid layouts must fall back to the default route")

local migrated = SaveSchema.sanitize({ Coins = 7, RollCount = 2 })
expect(migrated.SchemaVersion == SaveSchema.CurrentVersion, "legacy data must migrate to the current schema")
expect(migrated.Coins == 7 and migrated.RollCount == 2, "legacy values should be retained when valid")
local fractionalCoins = SaveSchema.sanitize({ Coins = 5.75 })
expect(fractionalCoins.Coins == 5.75, "two-decimal cube value payouts must survive persistence")

local migratedFiveAreaSave = SaveSchema.sanitize({
	SchemaVersion = 1,
	Coins = 7,
	Capacity = 3,
	Inventory = {},
	Layout = { "BasicDropper", "Giantifier", "ValueMultiplier", "CooldownTuner", "Seller" },
})
expect(migratedFiveAreaSave.SchemaVersion == 4, "legacy saves must advance to the current schema")
expect(migratedFiveAreaSave.Capacity == FactoryConfig.MaxFactoryCapacity, "legacy capacity must be clamped to the new slot count")
expect(migratedFiveAreaSave.Layout[5] == "Seller" and migratedFiveAreaSave.Layout[4] == nil, "legacy Seller must remain in the terminal bay")
expect(migratedFiveAreaSave.Inventory.CooldownTuner == 1, "a processor displaced by the smaller conveyor must return to inventory")

local migratedSeller = SaveSchema.sanitize({
	SchemaVersion = 2,
	Capacity = 2,
	Inventory = { FastDropper = 1 },
	Layout = { "BasicDropper", "ValueMultiplier", "Seller", nil },
})
expect(migratedSeller.Layout[3] == nil and migratedSeller.Layout[5] == "Seller", "old movable sellers must move to the fifth-area seller bay")
expect(migratedSeller.Inventory.FastDropper == 1 and next(migratedSeller.BoosterInventory) == nil, "migration should preserve owned machines and start with no boosters")

local future = SaveSchema.sanitize({ SchemaVersion = SaveSchema.CurrentVersion + 1, Coins = 999 })
expect(future.Coins == 0, "future schema data must not be trusted")
expect(future.Layout[1] == FactoryLayout.Default[1], "future schema data must use safe defaults")

local currentFourAreaSave = SaveSchema.sanitize({
	SchemaVersion = 3,
	Capacity = 2,
	Layout = { "BasicDropper", "ValueMultiplier", nil, "Seller" },
})
expect(currentFourAreaSave.SchemaVersion == 4 and currentFourAreaSave.Capacity == 2, "current four-area data should upgrade without losing capacity")
expect(currentFourAreaSave.Layout[4] == nil and currentFourAreaSave.Layout[5] == "Seller", "four-area saves should move their Seller to the expanded terminal bay")

print("Phase 5 persistence tests passed")
