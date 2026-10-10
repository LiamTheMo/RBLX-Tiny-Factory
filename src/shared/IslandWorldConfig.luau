--!strict
-- World-space factory origins preserve the existing left-to-right simulation.
local Config = {
	MapKey = "WorkshopAmberIslands",
	Revision = 1,
	GroundY = 8,
	WaterY = -2,
	IslandRadius = 180,
	PlotCount = 6,
}

function Config.getPlotOrigin(index: number): { X: number, Y: number, Z: number }
	assert(index >= 1 and index <= Config.PlotCount and index % 1 == 0, "invalid island index")
	local angle = (index - 1) * math.pi / 3
	return { X = math.cos(angle) * Config.IslandRadius - 15, Y = Config.GroundY, Z = math.sin(angle) * Config.IslandRadius }
end

function Config.findFreePlot(occupied: { [number]: boolean }): number?
	for index = 1, Config.PlotCount do
		if not occupied[index] then return index end
	end
	return nil
end

return Config
