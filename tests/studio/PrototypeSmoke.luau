-- Run with Studio's RunScript task against a Rojo-built local place.
-- The test uses an isolated play session and never publishes a place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
assert(workspace:FindFirstChild("PrototypeBaseplate"), "Rojo place is missing the baseplate")
assert(workspace:FindFirstChild("PrototypeSpawn"), "Rojo place is missing the spawn")

local resultEvent = Instance.new("RemoteEvent")
resultEvent.Name = "PrototypeTestResult"
resultEvent.Parent = ReplicatedStorage
local grantFunction = Instance.new("RemoteFunction")
grantFunction.Name = "PrototypeTestGrant"
grantFunction.Parent = ReplicatedStorage

local serverTest = Instance.new("Script")
serverTest.Name = "PrototypeServerTest"
serverTest.Source = [==[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local FactoryService = require(game.ServerScriptService.Server.Services.FactoryService)
local LootService = require(game.ServerScriptService.Server.Services.LootService)
local resultEvent = ReplicatedStorage.PrototypeTestResult
local grantFunction = ReplicatedStorage.PrototypeTestGrant

grantFunction.OnServerInvoke = function(player)
	local factory = FactoryService.getState(player)
	assert(factory, "factory missing during test grant")
	return factory.simulation:grantCoins(30)
end

resultEvent.OnServerEvent:Connect(function(player, success, message)
	if not success then
		warn("Prototype client test failed: " .. tostring(message))
		StudioTestService:EndTest("FAIL: " .. tostring(message))
		return
	end
	local factory = FactoryService.getState(player)
	local snapshot = factory.simulation:getSnapshot()
	assert(snapshot.ProducedItems > 0 and snapshot.SoldItems > 0 and snapshot.Coins > 0, "factory did not produce and sell")
	local loot = factory.plot:FindFirstChild("CoinDrop")
	assert(loot and loot:GetAttribute("OwnerUserId") == player.UserId, "world Coin drop missing")
	assert(loot:FindFirstChildOfClass("ProximityPrompt"), "Coin drop pickup missing")
	assert(LootService.claim(player, loot), "owner could not claim world drop")
	assert(not LootService.claim(player, loot), "world drop claimed twice")
	assert(player:GetAttribute("Analytics_LootCollected") == 1, "loot analytics missing")
	print("Prototype gameplay smoke test passed")
	StudioTestService:EndTest("Prototype gameplay smoke test passed")
end)

task.delay(25, function()
	StudioTestService:EndTest("FAIL: client test timed out")
end)
]==]
serverTest.Parent = game:GetService("ServerScriptService")

local clientTest = Instance.new("LocalScript")
clientTest.Name = "PrototypeClientTest"
clientTest.Source = [==[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local resultEvent = ReplicatedStorage:WaitForChild("PrototypeTestResult")
local grantFunction = ReplicatedStorage:WaitForChild("PrototypeTestGrant")

local success, message = pcall(function()
	local factory = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Factory")
	local roll = factory:WaitForChild("RollMachine")
	local place = factory:WaitForChild("PlaceMachine")
	local recycle = factory:WaitForChild("SellMachine")
	local buyCapacity = factory:WaitForChild("BuyCapacity")
	local state = factory:WaitForChild("GetEconomyState")
	local definition = require(ReplicatedStorage.Shared.MachineDefinitions)
	local economyRules = require(ReplicatedStorage.Shared.EconomyRules)
	local gui = player.PlayerGui:WaitForChild("EconomyHud")
	local dock = gui:WaitForChild("RollDock")
	assert(dock.AnchorPoint.X == 0.5 and dock.Position.X.Scale == 0.5 and dock.Position.Y.Scale == 1, "roll button is not bottom center")
	local rollButton = dock:FindFirstChild("Roll") :: TextButton?
	assert(rollButton, "roll button missing")
	assert(player.PlayerGui:WaitForChild("FactoryEffects"):FindFirstChild("CutsceneOverlay"), "cutscene overlay missing")

	task.wait(1)
	local before = state:InvokeServer()
	assert(before.Success and before.RollCost == 0, "free roll state missing")
	assert(rollButton.Text == "Roll", "ready roll button should say Roll")
	local first = roll:InvokeServer()
	assert(first.Success and first.LastRoll and first.RollCooldownRemaining > 0, "first free roll failed")
	task.wait(0.15)
	local machine = definition.get(first.LastRoll)
	assert(machine, "rolled machine definition missing")
	assert(machine.Rarity == economyRules.getRarityFromOdds(100 / machine.RollChance), "machine rarity did not follow its chance")
	local firstOdds = economyRules.getMachineOddsLabel(machine.Id, definition.getRollPool())
	local buildInventory = player.PlayerGui:WaitForChild("BuildHud"):WaitForChild("BuildPanel"):WaitForChild("InventoryList")
	local inventoryRow = buildInventory:WaitForChild("Machine_" .. first.LastRoll, 2) :: TextButton?
	assert(inventoryRow and inventoryRow:IsA("TextButton"), "rolled machine missing from build inventory")
	assert(firstOdds and inventoryRow.Text:find(firstOdds, 1, true), "inventory row omitted machine odds")
	local blocked = roll:InvokeServer()
	assert(not blocked.Success and blocked.Reason == "Roll cooldown active", "server cooldown failed")
	local slot = if machine.Category == "Producer" then 1 else 2
	local placed = place:InvokeServer(first.LastRoll, slot, true)
	assert(placed.Success, "rolled machine could not be placed")
	task.wait(3.1)
	local second = roll:InvokeServer()
	assert(second.Success and second.RollCount == first.RollCount + 1, "cooldown did not expire")
	local effects = require(player.PlayerScripts.Client.Controllers.EffectsController)
	effects.play("MachineRolled", { MachineId = second.LastRoll, Rarity = second.LastRarity })
	local overlay = player.PlayerGui.FactoryEffects.CutsceneOverlay
	assert(overlay.Visible, "roll cutscene did not open")
	task.wait(0.12)
	local rollingText = overlay.RevealCard.Text
	assert(rollingText:find("1/", 1, true) and rollingText:find("·", 1, true), "rolling animation should show odds and rarity in one line")
	local showsRollingRarity = false
	for _, band in ipairs(require(ReplicatedStorage.Shared.EconomyConfig).RarityOddsBands) do
		if rollingText:find(band.Name, 1, true) then
			showsRollingRarity = true
			break
		end
	end
	assert(showsRollingRarity, "rolling animation should show the sampled machine rarity")
	local secondMachine = definition.get(second.LastRoll)
	assert(secondMachine, "second rolled machine definition missing")
	assert(secondMachine.Rarity == economyRules.getRarityFromOdds(100 / secondMachine.RollChance), "second machine rarity did not follow its chance")
	local secondOdds = economyRules.getMachineOddsLabel(secondMachine.Id, definition.getRollPool())
	task.wait(1.7)
	assert(overlay.Heading.Text == string.upper(secondMachine.Rarity) .. " MACHINE!", "roll reveal rarity did not match the chance-derived tier")
	assert(secondOdds and overlay.RevealCard.Text:find(secondOdds, 1, true), "roll reveal omitted machine odds")
	assert(overlay.RevealCard.Text:find(secondMachine.Rarity, 1, true), "roll reveal omitted rarity from its one-line result")
	assert(overlay.RevealCard.TextWrapped == false, "roll reveal text should stay on one line")
	local textLimit = overlay.RevealCard:FindFirstChildOfClass("UITextSizeConstraint")
	assert(textLimit and textLimit.MaxTextSize <= 13, "roll reveal text should use a compact font")
	effects.play("UltraRareRollCutscene", { MachineName = "Test Machine", Rarity = "Legendary", Odds = "1/10001" })
	task.wait(0.1)
	assert(overlay.Visible and overlay.Heading.Text == "ULTRA RARE MACHINE!", "ultra-rare cutscene test event did not open")
	assert(overlay.RevealCard.Text:find("1/10001", 1, true), "ultra-rare cutscene omitted test odds")
	task.wait(0.15)
	local recycled = recycle:InvokeServer(second.LastRoll, 1)
	assert(recycled.Success, "free-roll recycling failed")
	assert(grantFunction:InvokeServer(), "test Coin grant failed")
	task.wait(0.15)
	local upgraded = buyCapacity:InvokeServer()
	assert(upgraded.Success and upgraded.Capacity == 2, "capacity purchase failed")
	task.wait(2)
end)

resultEvent:FireServer(success, tostring(message))
]==]
clientTest.Parent = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local result = StudioTestService:ExecutePlayModeAsync("PrototypeSmokeTest")
assert(result == "Prototype gameplay smoke test passed", tostring(result))
print(result)
