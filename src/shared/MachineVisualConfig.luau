--!strict

-- Temporary, data-driven placeholder visuals for the factory proof of concept.
-- New machine families can choose a VisualStyle in MachineDefinitions and add
-- a profile here without changing placement or simulation rules.
return {
	SlotPitch = 6,
	Conveyor = {
		SegmentOverlap = 0.08,
		BeltWidth = 2.8,
		DeckThickness = 0.22,
		DeckCenterY = 0.11,
		DeckColor = { 45, 49, 55 },
		RollerCountPerSlot = 6,
		RollerThickness = 0.12,
		RollerHeight = 0.08,
		RollerCenterY = 0.26,
		RollerOverhang = 0.08,
		RollerColor = { 164, 174, 183 },
		GuideHeight = 0.42,
		GuideThickness = 0.18,
		GuideColor = { 72, 82, 94 },
		GuideAccentHeight = 0.06,
		GuideAccentThickness = 0.04,
		GuideAccentColor = { 89, 213, 228 },
		SupportHeight = 0.22,
		SupportThickness = 0.28,
		SupportOffsetX = 2.15,
		SupportColor = { 57, 64, 73 },
		LabelHeight = 1.35,
		LabelColor = { 225, 239, 244 },
	},
	ConveyorItem = {
		Size = 0.9,
		LandingHeight = 0.75,
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
