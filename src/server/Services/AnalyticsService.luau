--!strict

local Players = game:GetService("Players")
local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsService = {}
local counters = {}
local started = false

local function attributeName(eventName: string): string
	return `Analytics_{eventName}`
end

local function isValidEventName(eventName: any): boolean
	return type(eventName) == "string" and #eventName > 0 and #eventName <= 48 and eventName:match("^[%a_][%w_]*$") ~= nil
end

function AnalyticsService.record(player: Player, eventName: string, amount: number?)
	if not isValidEventName(eventName) then
		return
	end
	local increment = amount or 1
	if type(increment) ~= "number" or increment < 0 or increment % 1 ~= 0 then
		return
	end
	counters[player] = counters[player] or {}
	local current = counters[player][eventName] or 0
	local nextValue = math.min(current + increment, 1_000_000)
	counters[player][eventName] = nextValue
	player:SetAttribute(attributeName(eventName), nextValue)
	pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, increment)
	end)
end

function AnalyticsService.restore(player: Player, snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	for eventName, count in pairs(snapshot) do
		if isValidEventName(eventName) and type(count) == "number" and count >= 0 and count % 1 == 0 then
			local restored = math.min(count, 1_000_000)
			counters[player] = counters[player] or {}
			counters[player][eventName] = restored
			player:SetAttribute(attributeName(eventName), restored)
		end
	end
end

function AnalyticsService.snapshot(player: Player): { [string]: number }
	local result = {}
	for eventName, count in pairs(counters[player] or {}) do
		result[eventName] = count
	end
	return result
end

function AnalyticsService.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		counters[player] = nil
	end)
end

return AnalyticsService
