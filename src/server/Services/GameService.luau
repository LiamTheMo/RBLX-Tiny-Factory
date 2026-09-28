--!strict

local FactoryService = require(script.Parent.FactoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local AssetShowcaseService = require(script.Parent.AssetShowcaseService)

local GameService = {}
local started = false

function GameService.start()
	if started then
		return
	end
	started = true
	task.spawn(AssetShowcaseService.start)
	FactoryService.start()
	EconomyService.start()
	DataService.start()
	AnalyticsService.start()
end

return GameService
