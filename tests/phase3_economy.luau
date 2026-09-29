--!strict

local EconomyRules = require("../src/shared/EconomyRules")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local firstRollCost = EconomyRules.getRollCost(0)
local secondRollCost = EconomyRules.getRollCost(1)
expect(firstRollCost == 0, "the first roll should be free")
expect(secondRollCost == 0, "every roll should be free")

local invalidRoll = EconomyRules.getRollCost(-1)
expect(not invalidRoll, "negative roll counts must be rejected")
expect(EconomyRules.getRollCooldownRemaining(13, 10) == 3, "server cooldown should report remaining time")
expect(EconomyRules.getRollCooldownRemaining(13, 15) == 0, "expired cooldown should be ready")
local canRoll = EconomyRules.canRoll(13, 15, 0)
expect(canRoll, "free roll should be available after cooldown")
local blockedCooldown = EconomyRules.canRoll(13, 11, 0)
expect(not blockedCooldown, "server cooldown should reject early rolls")
local blockedInventory = EconomyRules.canRoll(13, 15, 200)
expect(not blockedInventory, "full inventory should reject rolls")

local firstCapacityCost = EconomyRules.getCapacityCost(1)
local secondCapacityCost = EconomyRules.getCapacityCost(2)
local maxCapacityCost = EconomyRules.getCapacityCost(3)
expect(firstCapacityCost == 25, "first capacity expansion cost is incorrect")
expect(secondCapacityCost == 100, "second capacity expansion cost is incorrect")
expect(not maxCapacityCost, "maximum capacity must not have another upgrade")

expect(EconomyRules.weightedPick({ A = 1, B = 1 }, 0) ~= nil, "weighted selection should return a result")
expect(EconomyRules.weightedPick({ A = 1 }, 1) == nil, "out-of-range weighted selection must fail")
expect(EconomyRules.getResaleValue("Common") == 0, "free rolls must not mint Coins through resale")

print("Phase 3 economy tests passed")
