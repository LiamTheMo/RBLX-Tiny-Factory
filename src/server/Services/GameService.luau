--!strict

local FactoryService = require(script.Parent.FactoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EffectService = require(script.Parent.EffectService)
local LootService = require(script.Parent.LootService)
local BoosterService = require(script.Parent.BoosterService)
local IslandWorldBuilder = require(script.Parent.IslandWorldBuilder)

local GameService = {}
local started = false

function GameService.start()
	if started then
		return
	end
	started = true
	IslandWorldBuilder.build()
	EffectService.start()
	FactoryService.start()
	EconomyService.start()
	DataService.start()
	AnalyticsService.start()
	BoosterService.start()
	LootService.start()
end

return GameService
