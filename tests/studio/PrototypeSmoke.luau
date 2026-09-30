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
local findDropFunction = Instance.new("RemoteFunction")
findDropFunction.Name = "PrototypeTestFindDrop"
findDropFunction.Parent = ReplicatedStorage
local armDropFunction = Instance.new("RemoteFunction")
armDropFunction.Name = "PrototypeTestArmDrop"
armDropFunction.Parent = ReplicatedStorage

local serverTest = Instance.new("Script")
serverTest.Name = "PrototypeServerTest"
serverTest.Source = [==[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local FactoryService = require(game.ServerScriptService.Server.Services.FactoryService)
local LootService = require(game.ServerScriptService.Server.Services.LootService)
local EconomyService = require(game.ServerScriptService.Server.Services.EconomyService)
local resultEvent = ReplicatedStorage.PrototypeTestResult
local grantFunction = ReplicatedStorage.PrototypeTestGrant
local findDropFunction = ReplicatedStorage.PrototypeTestFindDrop
local armDropFunction = ReplicatedStorage.PrototypeTestArmDrop
local testDrops = {}
local lootCountBefore = {}

grantFunction.OnServerInvoke = function(player, grantKind)
	if grantKind == "Luck" then return EconomyService.grantLuckBoost(player, 2, 30) end
	local factory = FactoryService.getState(player)
	assert(factory, "factory missing during test grant")
	if grantKind == "SellerMachine" then
		factory.inventory.Seller = (factory.inventory.Seller or 0) + 1
		return true
	end
	return factory.simulation:grantCoins(1000)
end

findDropFunction.OnServerInvoke = function(player)
	local folder = workspace:WaitForChild("TinyFactoryBoosters", 15)
	if not folder then return nil end
	local deadline = os.clock() + 15
	repeat
		for _, candidate in ipairs(folder:GetChildren()) do
			if candidate:IsA("BasePart") and candidate:GetAttribute("SourcePlotUserId") == player.UserId
				and candidate:GetAttribute("Landed") == true then
				candidate.CanTouch = false
				testDrops[player] = candidate
				lootCountBefore[player] = player:GetAttribute("Analytics_LootCollected") or 0
				return candidate
			end
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

armDropFunction.OnServerInvoke = function(player, candidate)
	if candidate ~= testDrops[player] or not candidate or candidate.Parent ~= workspace:FindFirstChild("TinyFactoryBoosters")
		or candidate:GetAttribute("Landed") ~= true then return false end
	candidate.CanTouch = true
	return true
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
	local factoryLayout = require(game.ReplicatedStorage.Shared.FactoryLayout)
	local machineVisualConfig = require(game.ReplicatedStorage.Shared.MachineVisualConfig)
	assert(factoryLayout.SlotCount == 5, "prototype conveyor should have five placement areas")
	local conveyor = factory.conveyor
	assert(conveyor and conveyor.Parent == factory.plot, "visible conveyor assembly is missing from the player's plot")
	assert(conveyor:GetAttribute("SlotCount") == factoryLayout.SlotCount, "conveyor slot count should come from shared layout data")
	assert(conveyor:FindFirstChild("Conveyor_6") == nil, "prototype conveyor should not create an unexpected sixth area")
	local platform = factory.plot:FindFirstChild("FactoryPlatform")
	assert(platform and platform:IsA("BasePart") and platform.Size.X >= 36 and platform.Size.Z >= 14, "factory platform should frame the visible conveyor")
	local underframe = conveyor:FindFirstChild("ConveyorUnderframe")
	assert(underframe and underframe:IsA("BasePart"), "raised conveyor underframe is missing")
	for slotIndex = 1, factoryLayout.SlotCount do
		local belt = conveyor:FindFirstChild("Conveyor_" .. slotIndex)
		local clickDetector = belt and belt:FindFirstChild("FactorySlotClick")
		assert(belt and belt:IsA("BasePart") and belt.Size.X >= machineVisualConfig.SlotPitch and belt.Size.Z >= 4.5, "conveyor slot should be wide and form a continuous belt segment")
		assert(belt.Position.Y >= 2.5 and belt.Material == Enum.Material.Rubber, "raised conveyor belt surface is missing")
		assert(clickDetector and clickDetector:IsA("ClickDetector") and clickDetector.MaxActivationDistance > 0, "factory area is not clickable")
		local roller = conveyor:FindFirstChild("ConveyorRoller_" .. slotIndex .. "_1")
		assert(roller and roller:IsA("BasePart") and roller.Shape == Enum.PartType.Cylinder, "visible cylindrical conveyor rollers are missing")
		local guide = conveyor:FindFirstChild("ConveyorGuide_" .. slotIndex .. "_1")
		assert(guide and guide:IsA("BasePart") and guide.Size.Y >= 0.8, "raised conveyor guard rails are missing")
		local areaLabel = belt:FindFirstChild("ConveyorAreaLabel_" .. slotIndex)
		local areaText = areaLabel and areaLabel:FindFirstChild("Label")
		assert(areaText and areaText:IsA("TextLabel") and areaText.Text == factoryLayout.getAreaLabel(slotIndex) and areaText.TextSize >= 16, "conveyor placement area label is not visible")
	end
	local machineFolder = factory.plot:FindFirstChild("Machines")
	local hasDropper = false
	if machineFolder then
		for _, machineModel in ipairs(machineFolder:GetChildren()) do
			assert(not machineModel:FindFirstChild("MachineLabel", true), "placed-machine holograms should be hidden")
			assert(machineModel:GetAttribute("VisualVariant") and machineModel:FindFirstChild("MachineBadge", true), "machine variants and housing symbols must be visible")
			if machineModel:FindFirstChild("DropperHousing", true) then
				hasDropper = true
			end
		end
	end
	assert(hasDropper, "temporary dropper proof-of-concept model is missing")
	local sellerHitbox = factory.sellerHitbox
	assert(sellerHitbox and sellerHitbox.Name == "SellerHitbox" and sellerHitbox.Transparency == 1 and not sellerHitbox.CanCollide, "seller hitbox should be invisible and non-colliding")
	local loot = testDrops[player]
	assert(loot and loot:GetAttribute("Claimed") == true and loot.Parent == nil, "running over the world booster did not claim it")
	assert(loot:GetAttribute("Landed") == true and loot.Position.Y >= 0.5 and loot.Transparency == 0, "booster should fade in and land above the baseplate")
	assert(not LootService.claim(player, loot), "world booster claimed twice")
	assert((player:GetAttribute("Analytics_LootCollected") or 0) == lootCountBefore[player] + 1, "booster pickup analytics missing")
	print("Prototype gameplay smoke test passed")
	StudioTestService:EndTest("Prototype gameplay smoke test passed")
end)

task.delay(45, function()
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
local findDropFunction = ReplicatedStorage:WaitForChild("PrototypeTestFindDrop")
local armDropFunction = ReplicatedStorage:WaitForChild("PrototypeTestArmDrop")

local success, message = pcall(function()
	local factory = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Factory")
	local roll = factory:WaitForChild("RollMachine")
	local place = factory:WaitForChild("PlaceMachine")
	local recycle = factory:WaitForChild("SellMachine")
	local buyCapacity = factory:WaitForChild("BuyCapacity")
	local state = factory:WaitForChild("GetEconomyState")
	local getFactoryState = factory:WaitForChild("GetFactoryState")
	local definition = require(ReplicatedStorage.Shared.MachineDefinitions)
	local economyRules = require(ReplicatedStorage.Shared.EconomyRules)
	local gui = player.PlayerGui:WaitForChild("EconomyHud")
	local dock = gui:WaitForChild("RollDock")
	assert(dock.AnchorPoint.X == 0.5 and dock.Position.X.Scale == 0.5 and dock.Position.Y.Scale == 1, "roll button is not bottom center")
	assert(dock.BackgroundTransparency == 1, "roll control should not have a gray backing panel")
	assert(gui.EconomyPanel:FindFirstChild("RollResult") == nil, "roll output should stay in the text-only reveal")
	local rollButton = dock:FindFirstChild("Roll") :: TextButton?
	assert(rollButton, "roll button missing")
	assert(player.PlayerGui:WaitForChild("FactoryEffects"):FindFirstChild("CutsceneOverlay"), "cutscene overlay missing")

	local formatter = require(ReplicatedStorage.Shared.NumberFormatter)
	local initialCoins = player:GetAttribute("FactoryCoins") or 0
	local incomeDeadline = os.clock() + 7
	repeat task.wait(0.1) until (player:GetAttribute("FactoryCoins") or 0) > initialCoins or os.clock() >= incomeDeadline
	assert((player:GetAttribute("FactoryCoins") or 0) > initialCoins, "seller must credit Coins without any inventory action")
	task.wait(0.15)
	assert(gui.EconomyPanel.EconomyStatus.Text:find("Coins " .. formatter.format(player:GetAttribute("FactoryCoins")), 1, true), "Coins HUD must reflect production income live")
	local hover = require(player.PlayerScripts.Client.Controllers.CubeHoverController)
	local plots = workspace.TinyFactoryPlots
	local ownedPlot = plots:FindFirstChild("Factory_" .. player.UserId)
	local cube = nil
	local hoverDeadline = os.clock() + 4
	repeat
		for _, child in ipairs(ownedPlot:GetChildren()) do
			if child:IsA("BasePart") and child:GetAttribute("FactoryItem") then cube = child; break end
		end
		if not cube then task.wait(0.1) end
	until cube or os.clock() >= hoverDeadline
	assert(cube and hover.focusItem(cube), "a cube must be inspectable")
	local tooltip = player.PlayerGui.CubeValueHover
	assert(tooltip.Enabled and tooltip.Adornee == cube and tooltip.Frame.Value.Text:find("Coins", 1, true), "hover value label is missing")
	assert(tooltip.Frame.Modifiers.Text:find("chain ×", 1, true) and tooltip.Frame.Modifiers.Text:find("sale ×", 1, true), "hover must show upgrade and sale multipliers")
	local effects = require(player.PlayerScripts.Client.Controllers.EffectsController)
	effects.play("ItemSold", { Coins = 1234, Position = cube.Position })
	local popup = nil
	for _, child in ipairs(workspace:GetChildren()) do
		local amount = child:FindFirstChild("Amount", true)
		if child.Name == "SalePopup" and amount and amount.Text:find("+1.23k Coins", 1, true) then popup = child; break end
	end
	assert(popup, "confirmed sales must display formatted floating currency")
	task.wait(0.3)
	assert(popup.FloatingCoins.StudsOffsetWorldSpace.Y > 0.5, "sale popup must rise")
	task.wait(1)
	assert(popup.Parent == nil, "sale popups must clean themselves up")
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
	assert(grantFunction:InvokeServer("Luck"), "timed Luck booster grant failed")
	local luckyState = state:InvokeServer()
	assert(luckyState.LuckMultiplier == 2 and luckyState.LuckExpiresAt > workspace:GetServerTimeNow(), "Luck state was not synchronized")
	local inventoryController = require(player.PlayerScripts.Client.Controllers.InventoryController)
	local inventoryHud = player.PlayerGui:WaitForChild("FactoryInventoryHud")
	assert(inventoryHud:FindFirstChild("InventoryButton"), "persistent inventory button is missing")
	inventoryController.openInventory()
	task.wait(0.15)
	local inventoryList = inventoryHud.MachinePanel:WaitForChild("MachineList")
	local inventoryRow = inventoryList:WaitForChild("Owned_" .. first.LastRoll, 2)
	assert(inventoryRow and inventoryRow:IsA("Frame"), "rolled machine missing from owned inventory")
	local machineDetails = inventoryRow:FindFirstChild("MachineDetails") :: TextLabel?
	assert(firstOdds and machineDetails and machineDetails.Text:find(firstOdds, 1, true), "inventory row omitted machine odds")
	local blocked = roll:InvokeServer()
	assert(not blocked.Success and blocked.Reason == "Roll cooldown active", "server cooldown failed")
	local slot = if machine.Category == "Producer" then 1 elseif machine.Category == "Seller" then factoryLayout.SellerSlotIndex else 2
	local placed = place:InvokeServer(first.LastRoll, slot, true)
	assert(placed.Success, "rolled machine could not be placed")
	inventoryController.openPlacement(slot)
	task.wait(0.1)
	assert(inventoryHud.MachinePanel.PanelTitle.Text == (if slot == factoryLayout.SellerSlotIndex then "Select Seller" else "Place in Area " .. slot), "click-to-place inventory did not open for the selected area")
	inventoryController.close()
	task.wait(3.1)
	local second = roll:InvokeServer()
	assert(second.Success and second.RollCount == first.RollCount + 1, "cooldown did not expire")
	effects.play("MachineRolled", { MachineId = second.LastRoll, Rarity = second.LastRarity, LuckMultiplier = second.LastRollLuckMultiplier })
	local overlay = player.PlayerGui.FactoryEffects.CutsceneOverlay
	assert(overlay.Visible, "roll cutscene did not open")
	task.wait(0.12)
	local rollingText = overlay.RevealCard.Text
	assert(overlay.BackgroundColor3 == Color3.fromRGB(92, 96, 104) and overlay.BackgroundTransparency == 0.28, "normal roll should use the stronger gray screen overlay")
	assert(overlay.Heading.BackgroundTransparency == 1, "roll heading should be text without a backing fill")
	assert(overlay.RevealCard.BackgroundTransparency == 1, "rolling result should be text without a card fill")
	assert(not overlay.RevealCard:FindFirstChildOfClass("UIStroke"), "rolling result should not have a box outline")
	assert(rollingText:find("1/", 1, true) and rollingText:find("·", 1, true), "roll animation should show odds on one line")
	for _, band in ipairs(require(ReplicatedStorage.Shared.EconomyConfig).RarityOddsBands) do
		assert(not rollingText:find(band.Name, 1, true), "rarity should stay in the heading, not the result line")
	end
	local secondMachine = definition.get(second.LastRoll)
	assert(secondMachine and second.LastRollLuckMultiplier == 2, "second roll did not use active Luck")
	local activeRollPool = economyRules.getLuckAdjustedRollPool(definition.getRollPool(), second.LastRollLuckMultiplier)
	local secondRarity = economyRules.getMachineRarity(secondMachine.Id, activeRollPool)
	local secondOdds = economyRules.getMachineOddsLabel(secondMachine.Id, activeRollPool)
	task.wait(1.7)
	assert(overlay.Heading.Text == string.upper(secondRarity) .. " MACHINE!", "roll reveal rarity did not match active chance-derived tier")
	assert(secondOdds and overlay.RevealCard.Text:find(secondOdds, 1, true), "roll reveal omitted machine odds")
	assert(not overlay.RevealCard.Text:find(secondRarity, 1, true), "roll result should not repeat rarity by the heading")
	assert(overlay.RevealCard.TextWrapped == true, "large roll reveal text should wrap when needed")
	local textLimit = overlay.RevealCard:FindFirstChildOfClass("UITextSizeConstraint")
	assert(textLimit and textLimit.MinTextSize >= 28 and textLimit.MaxTextSize >= 56, "roll reveal text should use the larger readable type scale")
	effects.play("UltraRareRollCutscene", { MachineName = "Test Machine", Rarity = "Legendary", Odds = "1/10001" })
	task.wait(0.1)
	assert(overlay.Visible and overlay.Heading.Text == "ULTRA RARE MACHINE!", "ultra-rare cutscene test event did not open")
	assert(overlay.BackgroundTransparency == 0.28, "ultra-rare roll reveal should keep the gray overlay")
	assert(overlay.RevealCard.BackgroundTransparency == 1, "ultra-rare reveal should keep its text background clear")
	assert(overlay.RevealCard.Text:find("1/10001", 1, true), "ultra-rare cutscene omitted test odds")
	task.wait(0.15)
	local toast = player.PlayerGui.FactoryEffects:FindFirstChild("EventToast") :: TextLabel?
	assert(not toast or not toast.Text:find("Added to inventory", 1, true), "roll completion should not show an added-to-inventory toast")
	local recycled = recycle:InvokeServer(second.LastRoll, 1)
	assert(recycled.Success, "free-roll recycling failed")
	assert(grantFunction:InvokeServer(), "test Coin grant failed")
	task.wait(0.15)
	local upgraded = buyCapacity:InvokeServer()
	assert(upgraded.Success and upgraded.Capacity == 2, "first capacity purchase failed")
	assert(grantFunction:InvokeServer(), "test Coins for the second capacity purchase failed")
	task.wait(0.15)
	local secondUpgrade = buyCapacity:InvokeServer()
	assert(secondUpgrade.Success and secondUpgrade.Capacity == 3, "second capacity purchase failed")
	assert(secondUpgrade.CapacityCost == nil, "maximum capacity should not advertise another purchase")
	assert(grantFunction:InvokeServer("SellerMachine"), "test Seller grant failed")
	task.wait(0.15)
	inventoryController.openPlacement(factoryLayout.SellerSlotIndex)
	task.wait(0.1)
	assert(inventoryHud.MachinePanel.PanelTitle.Text == "Select Seller", "seller bay should open seller selection")
	assert(inventoryHud.MachinePanel.MachineList:FindFirstChild("Place_Seller_1"), "seller selection should show an owned Seller")
	assert(not inventoryHud.MachinePanel.MachineList:FindFirstChild("Place_ValueMultiplier_1"), "seller selection should hide upgraders")
	local blockedSeller = place:InvokeServer("Seller", 3, false)
	assert(not blockedSeller.Success, "seller should be rejected outside the seller bay")
	task.wait(0.15)
	local placedSeller = place:InvokeServer("Seller", factoryLayout.SellerSlotIndex, true)
	assert(placedSeller.Success, "owned Seller could not replace the current seller in the bay")
	task.wait(0.15)
	local movedSeller = factory:WaitForChild("MoveMachine"):InvokeServer(factoryLayout.SellerSlotIndex, 3)
	assert(not movedSeller.Success, "seller should not move into an upgrader area")
	local movedState = getFactoryState:InvokeServer()
	assert(movedState.Success and movedState.Layout[5] == "Seller", "seller bay must stay at the route end")
	inventoryController.openInventory()
	task.wait(0.1)
	local sellerRow = inventoryHud.MachinePanel.MachineList:FindFirstChild("Owned_Seller")
	assert(sellerRow and sellerRow:FindFirstChild("MachineDetails"), "owned inventory omitted the Seller")
	for _, section in ipairs({ "Droppers", "Upgraders", "Sellers" }) do
		assert(inventoryHud.MachinePanel.MachineList:FindFirstChild("Section_" .. section), "machine inventory section missing: " .. section)
	end
	assert(inventoryHud.MachinePanel:FindFirstChild("BoostersTab"), "booster tab is missing")
	local targetDrop = findDropFunction:InvokeServer()
	assert(targetDrop and targetDrop:IsA("BasePart") and targetDrop:GetAttribute("Landed") == true and not targetDrop.CanTouch, "test booster was not held after landing")
	assert(not targetDrop:FindFirstChildOfClass("ProximityPrompt"), "world booster should not need an interaction prompt")
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	root.CFrame = CFrame.new(targetDrop.Position + Vector3.new(0, 8, 0))
	assert(armDropFunction:InvokeServer(targetDrop), "test booster touch could not be armed")
	root.CFrame = CFrame.new(targetDrop.Position + Vector3.new(0, 1.5, 0))
	task.wait(1)
	local boosterId = targetDrop:GetAttribute("BoosterId")
	local collected = getFactoryState:InvokeServer()
	assert(collected.BoosterInventory[boosterId] >= 1, "picked-up booster was not stored")
	inventoryController.openInventory()
	inventoryHud.MachinePanel.BoostersTab:Activate()
	task.wait(0.1)
	assert(inventoryHud.MachinePanel.MachineList:FindFirstChild("Booster_" .. boosterId), "collected booster missing from inventory tab")
	local used = factory:WaitForChild("UseBooster"):InvokeServer(boosterId)
	assert(used.Success, "stored booster could not be used")
	local afterUse = getFactoryState:InvokeServer()
	assert((afterUse.BoosterInventory[boosterId] or 0) == collected.BoosterInventory[boosterId] - 1, "using booster should consume exactly one")
end)

resultEvent:FireServer(success, tostring(message))
]==]
clientTest.Parent = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local result = StudioTestService:ExecutePlayModeAsync("PrototypeSmokeTest")
assert(result == "Prototype gameplay smoke test passed", tostring(result))
print(result)
