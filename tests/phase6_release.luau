--!strict

local FactoryConfig = require("../src/shared/FactoryConfig")
local FactorySimulation = require("../src/shared/FactorySimulation")

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

expect(FactoryConfig.BuildVersion == "v1.00", "the release build must identify as v1.00")
local valid, configurationError = FactorySimulation.validateConfiguration()
expect(valid, configurationError or "release configuration must validate")
expect(FactoryConfig.MaxActiveItems <= 24, "release active-item cap must remain bounded")
expect(FactoryConfig.MaxFactoryCapacity == 2, "four conveyor areas allow two processor slots")

print("Phase 6 release tests passed")
