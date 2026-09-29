--!strict

-- Client controllers handle presentation and input; server services own game state.
local ClientController = {}
local started = false
local BuildController = require(script.Parent.BuildController)
local EconomyController = require(script.Parent.EconomyController)
local EffectsController = require(script.Parent.EffectsController)
local InventoryController = require(script.Parent.InventoryController)

function ClientController.start()
	if started then
		return
	end
	started = true
	EffectsController.start()
	InventoryController.start()
	BuildController.start()
	EconomyController.start()
end

return ClientController
