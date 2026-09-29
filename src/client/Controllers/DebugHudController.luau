--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local DebugHudController = {}
local started = false

local function createLabel(parent: Instance, name: string, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(28, 24, 21)
	label.BorderSizePixel = 0
	label.Position = position
	label.Size = UDim2.fromOffset(260, 28)
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function DebugHudController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TinyFactoryHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local title = createLabel(screenGui, "Title", UDim2.fromOffset(16, 16))
	title.Text = `Tiny Factory — {player:GetAttribute("FactoryBuildVersion") or "v1.00"}`
	local coins = createLabel(screenGui, "Coins", UDim2.fromOffset(16, 50))
	local activeItems = createLabel(screenGui, "ActiveItems", UDim2.fromOffset(16, 84))
	local production = createLabel(screenGui, "Production", UDim2.fromOffset(16, 118))
	local sold = createLabel(screenGui, "Sold", UDim2.fromOffset(16, 152))
	local capacity = createLabel(screenGui, "Capacity", UDim2.fromOffset(16, 186))
	local dataStatus = createLabel(screenGui, "DataStatus", UDim2.fromOffset(16, 220))
	local guide = createLabel(screenGui, "Guide", UDim2.fromOffset(16, 254))
	guide.Size = UDim2.fromOffset(260, 44)
	guide.BackgroundColor3 = Color3.fromRGB(42, 62, 49)
	guide.TextColor3 = Color3.fromRGB(255, 224, 140)
	guide.TextSize = 13
	guide.TextWrapped = true
	guide.TextYAlignment = Enum.TextYAlignment.Center

	local function refresh()
		coins.Text = `Coins: {player:GetAttribute("FactoryCoins") or 0}`
		activeItems.Text = `Active items: {player:GetAttribute("FactoryActiveItems") or 0}`
		production.Text = `Produced: {player:GetAttribute("FactoryProducedItems") or 0}`
		sold.Text = `Sold: {player:GetAttribute("FactorySoldItems") or 0}`
		capacity.Text = `Capacity: {player:GetAttribute("FactoryCapacity") or 1}`
		if player:GetAttribute("FactoryDataLocked") then
			dataStatus.Text = "Save: another session is active"
		elseif player:GetAttribute("FactoryDataLoaded") then
			dataStatus.Text = "Save: loaded"
		elseif player:GetAttribute("FactoryDataError") then
			dataStatus.Text = "Save: unavailable; playing safely"
		else
			dataStatus.Text = "Save: loading"
		end

		local rolls = player:GetAttribute("Analytics_MachineRolled") or 0
		local placements = player:GetAttribute("Analytics_MachinePlaced") or 0
		local sales = player:GetAttribute("Analytics_MachineSold") or 0
		if rolls == 0 then
			guide.Text = "Start here: roll a machine, then open Build factory to place it."
		elseif placements == 0 then
			guide.Text = "Next: select your new machine in Build factory and choose an open slot."
		elseif sales == 0 then
			guide.Text = "Keep going: let the route run, then sell an extra machine from inventory."
		else
			guide.Text = "Core loop: roll, place, produce, sell, and expand your factory."
		end
	end

	for _, attributeName in ipairs({
		"FactoryCoins",
		"FactoryActiveItems",
		"FactoryProducedItems",
		"FactorySoldItems",
		"FactoryCapacity",
		"FactoryDataLoaded",
		"FactoryDataLocked",
		"FactoryDataError",
		"FactoryBuildVersion",
		"Analytics_MachineRolled",
		"Analytics_MachinePlaced",
		"Analytics_MachineSold",
	}) do
		player:GetAttributeChangedSignal(attributeName):Connect(refresh)
	end
	local camera = workspace.CurrentCamera
	if camera then
		local function layout()
			local viewportWidth = camera.ViewportSize.X
			local compact = viewportWidth < 760 or (UserInputService.TouchEnabled and viewportWidth < 1000)
			screenGui.Enabled = not compact
			if compact then
				return
			end
			for _, label in ipairs({ title, coins, activeItems, production, sold, capacity, dataStatus }) do
				label.Size = UDim2.fromOffset(260, 28)
				label.TextSize = 16
			end
			guide.Size = UDim2.fromOffset(260, 44)
			guide.TextSize = 13
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		layout()
	end
	refresh()
end

return DebugHudController
