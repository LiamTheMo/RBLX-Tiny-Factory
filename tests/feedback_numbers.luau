--!strict

local Format = require("../src/shared/NumberFormatter")
local Geometry = require("../src/shared/FactoryItemGeometry")
local Config = require("../src/shared/FactoryConfig")
local Visuals = require("../src/shared/MachineVisualConfig")
local Layout = require("../src/shared/FactoryLayout")
local Machines = require("../src/shared/MachineDefinitions")
local Simulation = require("../src/shared/FactorySimulation")
local Sale = require("../src/shared/SaleValueRules")
local Save = require("../src/shared/SaveSchema")

local function expect(condition: boolean, message: string)
	if not condition then error(message, 2) end
end

local cases = {
	{ 0, "0.00" }, { 12.345, "12.35" }, { -1250, "-1.25k" },
	{ 1000, "1.00k" }, { 1e6, "1.00m" }, { 1e9, "1.00b" },
	{ 1e12, "1.00t" }, { 1e15, "1.00qd" }, { 1e18, "1.00qt" },
	{ 1e21, "1.00sx" }, { 1e24, "1.00sp" }, { 1e27, "1.00oc" },
	{ 1e30, "1.00no" }, { 1e33, "1.00dc" }, { 1e36, "1.00udc" },
	{ 1e303, "1.00ct" }, { 999_999, "1.00m" }, { 999.999, "1.00k" },
	{ -0.0001, "0.00" },
}
for _, case in ipairs(cases) do
	expect(Format.format(case[1] :: number) == case[2], `format failed for {case[1]}: {Format.format(case[1] :: number)}`)
end
expect(#Format.Suffixes == 102, "formatter should cover suffixes through centillion")
expect(Format.format(1e308) == "100000.00ct", "largest finite magnitudes must not overflow formatting")
expect(Format.format(0 / 0) == "0.00" and Format.format(math.huge) == "∞", "non-finite display inputs need safe fallbacks")
expect(Format.integer(24) == "24" and Format.integer(1234) == "1.23k", "count formatting should be reusable")

local colors = {}
for id in pairs(Machines.all()) do
	local variant = Visuals.Variants[id]
	expect(variant and variant.Symbol and #variant.Parts > 0, `machine {id} needs a visible variant`)
	local key = table.concat(variant.PrimaryColor, ",")
	expect(not colors[key], `machine {id} should have a distinct palette`)
	colors[key] = true
end

-- Exercise the same cube placement/contact math used by the server with an
-- empty conveyor area and both ordinary and enlarged cube sizes.
for _, scale in ipairs({ 1, 1.8, 4 }) do
	local item = { SlotIndex = 3, ReadyForSale = true, TimeRemaining = 0, SizeScale = scale }
	local x, y, size = Geometry.itemPosition(Layout.Default, item)
	local box = Visuals.SellerHitbox
	local sellerX = (Layout.SellerSlotIndex - 1) * Visuals.SlotPitch + box.Offset[1]
	local sellerY = Geometry.machineLift() + box.Offset[2]
	expect(x == sellerX, "ready cube must be positioned at the physical seller bay")
	expect(Geometry.overlapsBox(x - sellerX, y - sellerY, 0, box.Size[1], box.Size[2], box.Size[3], size), "cube should contact the seller at its actual conveyor height")
	expect(not Geometry.overlapsBox(x - sellerX - 20, y - sellerY, 0, box.Size[1], box.Size[2], box.Size[3], size), "an upstream cube must not contact the seller")
end

local changedLayout = { "BasicDropper", "ValueMultiplier", "Giantifier", "Seller" }
local readyX = Geometry.itemPosition(changedLayout, { SlotIndex = 3, ReadyForSale = true, TimeRemaining = 0, SizeScale = 1 })
expect(readyX == (Layout.SellerSlotIndex - 1) * Visuals.SlotPitch, "ready cubes must stay at the Seller even after an in-flight route edit")

local sim = Simulation.new({ SpawnIntervalSeconds = 10 })
sim:setCoins(Config.MaxItemValue)
sim:step(Config.TravelTimePerSlotSeconds * 2 + 0.01)
local item = assert(sim:getActiveItemsForDebug()[1])
expect(item.ReadyForSale and item.BaseValue == 1 and #item.ModifierLabels == 1, "cube must retain its base value and upgrades")
local preview = assert(Sale.getBreakdown(item.Value, item.TypeModifiers, nil, Machines.get("Seller").SaleModifiers, Config.MaxItemValue))
local sold, amount = sim:sellItem(item.Id)
expect(sold and amount == preview.Value and sim:getSnapshot().Coins == Config.MaxItemValue + 2, "sales must increase the wallet beyond the per-cube cap")
expect(not sim:sellItem(item.Id), "the sale event must never duplicate a payout")
expect(Save.sanitize({ Coins = Config.MaxItemValue + 2 }).Coins == Config.MaxItemValue + 2, "saves must preserve wallets above the cube cap")
sim:setCoins(Config.MaxCoins - 1)
sim:grantCoins(100)
expect(sim:getSnapshot().Coins == Config.MaxCoins, "wallet must remain within exact integer bounds")
expect(Save.sanitize({ Coins = math.huge }).Coins == Config.MaxCoins, "untrusted saves must respect the wallet cap")

print("Factory feedback and number formatting tests passed")
