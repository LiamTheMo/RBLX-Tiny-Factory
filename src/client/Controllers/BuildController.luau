--!strict

local Players = game:GetService("Players")
local InventoryController = require(script.Parent.InventoryController)

local BuildController = {}
local started = false

function BuildController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local plotsFolder = workspace:WaitForChild("TinyFactoryPlots")
	local connectedDetectors: { [ClickDetector]: boolean } = setmetatable({}, { __mode = "k" })

	local function connectPhysicalSlot(instance: Instance)
		if not instance:IsA("ClickDetector") or instance.Name ~= "FactorySlotClick" or connectedDetectors[instance] then
			return
		end

		local ancestor = instance.Parent
		local ownedPlot = false
		while ancestor and ancestor ~= plotsFolder do
			if ancestor:GetAttribute("OwnerUserId") == player.UserId then
				ownedPlot = true
				break
			end
			ancestor = ancestor.Parent
		end
		if not ownedPlot then
			return
		end

		local slotIndex = instance:GetAttribute("FactorySlotIndex")
		if type(slotIndex) ~= "number" then
			return
		end
		connectedDetectors[instance] = true
		instance.MouseClick:Connect(function(clicker: Player)
			if clicker == player then
				InventoryController.openPlacement(slotIndex)
			end
		end)
	end

	for _, instance in ipairs(plotsFolder:GetDescendants()) do
		connectPhysicalSlot(instance)
	end
	plotsFolder.DescendantAdded:Connect(connectPhysicalSlot)
end

return BuildController
