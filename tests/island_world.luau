--!strict
local Config = require("../src/shared/IslandWorldConfig")
local occupied = {}
local origins = {}
for i = 1, Config.PlotCount do
	assert(Config.findFreePlot(occupied) == i, "allocate the first free island")
	occupied[i] = true
	local p = Config.getPlotOrigin(i)
	assert(p.Y == Config.GroundY, "factories sit on island ground")
	for _, other in origins do
		local dx, dz = p.X-other.X, p.Z-other.Z
		assert(dx*dx+dz*dz > 120*120, "island factories must remain physically isolated")
	end
	table.insert(origins,p)
end
assert(Config.findFreePlot(occupied) == nil, "a full server never creates a factory in water")
occupied[3] = nil
assert(Config.findFreePlot(occupied) == 3, "departed players release their island")
for _, bad in {0,7,1.5,-1} do
	assert(not pcall(Config.getPlotOrigin,bad), "reject invalid island indices")
end
print("Island allocation and isolation tests passed")
