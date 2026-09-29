--!strict

-- Keep presentation and input in client controllers while all game mutations
-- remain server-authoritative.
local ClientController = {}
local started = false
local DebugHudController = require(script.Parent.DebugHudController)
local BuildController = require(script.Parent.BuildController)
local EconomyController = require(script.Parent.EconomyController)
local EffectsController = require(script.Parent.EffectsController)

function ClientController.start()
	if started then
		return
	end
	started = true
	EffectsController.start()
	DebugHudController.start()
	BuildController.start()
	EconomyController.start()
end

return ClientController
