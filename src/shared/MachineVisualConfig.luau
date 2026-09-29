--!strict

-- Temporary, data-driven placeholder visuals for the factory proof of concept.
-- New machine families can choose a VisualStyle in MachineDefinitions and add
-- a profile here without changing placement or simulation rules.
return {
	SlotPitch = 6,
	ConveyorItem = {
		Size = 0.9,
		LandingHeight = 0.62,
		DropStartHeight = 4.0,
		DropDurationSeconds = 0.16,
	},
	Profiles = {
		Dropper = {
			Style = "Dropper",
			PrimaryColor = { 82, 145, 255 },
			AccentColor = { 255, 194, 66 },
		},
		Processor = {
			Style = "Processor",
			PrimaryColor = { 255, 194, 66 },
			AccentColor = { 70, 53, 38 },
		},
		Seller = {
			Style = "Seller",
			PrimaryColor = { 83, 207, 113 },
			AccentColor = { 47, 105, 63 },
		},
	},
}
