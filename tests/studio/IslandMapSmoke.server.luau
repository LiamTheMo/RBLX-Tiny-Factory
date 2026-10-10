-- Install temporarily as a server Script in Studio; remove after the test.
-- Does not grant inventory, currency, or change durable factory state.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local FactoryService = require(game.ServerScriptService.Server.Services.FactoryService)
local Config = require(game.ReplicatedStorage.Shared.IslandWorldConfig)

local function run()
	local world = workspace:WaitForChild(Config.MapKey, 20)
	assert(world, "island world missing")
	local deadline = os.clock() + 20
	local player, factory
	repeat
		player = Players:GetPlayers()[1]
		factory = if player then FactoryService.getState(player) else nil
		if factory and player.Character and player:GetAttribute("FactoryDataReady") then break end
		task.wait(0.1)
	until os.clock() >= deadline
	assert(player and factory and factory.plotIndex, "factory island missing")
	local root = player.Character:WaitForChild("HumanoidRootPart", 10)
	assert(root, "character missing")
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.TinyFactoryPlots, player.Character }
	local groundChecks = 0
	for index = 1, Config.PlotCount do
		local origin = world:FindFirstChild(string.format("StarterIsland_%02d", index)).FactoryOrigin.Position
		for x = -22, 22, 11 do
			for z = -18, 18, 9 do
				local ray = workspace:Raycast(origin + Vector3.new(15 + x, 90, z), Vector3.new(0, -120, 0), params)
				assert(ray and ray.Normal.Y > 0.7, "missing ground on island " .. index)
				groundChecks += 1
			end
		end
	end
	local parts = 0
	for _, instance in world:GetDescendants() do
		if instance:IsA("BasePart") then
			assert(instance.Anchored, "unanchored map part")
			parts += 1
		end
	end
	assert(player.RespawnLocation and player.RespawnLocation:IsDescendantOf(world), "respawn assignment missing")
	local salesBefore = player:GetAttribute("FactorySoldItems") or 0
	root.CFrame = CFrame.new(factory.origin + Vector3.new(15, -20, 15))
	task.wait(0.8)
	assert(root.Position.Y > 0, "lagoon fall recovery failed")
	local respawnIsland = player.RespawnLocation.Parent
	player:LoadCharacterAsync()
	local newRoot = player.Character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.5)
	assert((newRoot.Position - (factory.origin + Vector3.new(15, 3, 15))).Magnitude < 8, "respawn left own island")
	assert(player.RespawnLocation.Parent == respawnIsland, "respawn island changed")
	task.wait(8)
	local salesAfter = player:GetAttribute("FactorySoldItems") or 0
	assert(salesAfter > salesBefore, "production did not sell during map test")
	return { Passed = true, Island = factory.plotIndex, GroundChecks = groundChecks,
		AnchoredParts = parts, FallRecovery = true, Respawn = true,
		SalesBefore = salesBefore, SalesAfter = salesAfter }
end

local ok, result = pcall(run)
if not ok then result = { Passed = false, Error = tostring(result) } end
workspace:SetAttribute("IslandQAResult", HttpService:JSONEncode(result))
print("Island map smoke: " .. HttpService:JSONEncode(result))
