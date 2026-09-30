--!strict

-- Temporary, data-driven proof-of-concept visuals for the factory route.
-- Conveyor dimensions and machine styles live here so the world presentation
-- can grow without changing placement rules or simulation behavior.
return {
	SlotPitch = 7.5,
	MachineProfileBaseDeckTop = 0.22,
	FactoryPlot = {
		SpacingX = 48,
		BaseLengthPadding = 8,
		BaseWidth = 16,
		BaseThickness = 0.6,
		BaseCenterY = -0.3,
		BaseColor = { 154, 119, 81 },
	},
	Conveyor = {
		Elevation = 1.5,
		SellerBay = {
			DeckColor = { 54, 47, 43 },
			AccentColor = { 240, 168, 143 },
			LabelColor = { 255, 218, 196 },
		},
		SegmentOverlap = 0.16,
		BeltWidth = 4.8,
		DeckThickness = 0.38,
		DeckCenterY = 1.25,
		DeckColor = { 34, 40, 48 },
		RollerCountPerSlot = 7,
		RollerDiameter = 0.22,
		RollerCenterY = 1.56,
		RollerOverhang = 0.16,
		RollerColor = { 202, 218, 223 },
		GuideHeight = 0.9,
		GuideThickness = 0.26,
		GuideColor = { 76, 94, 107 },
		GuideAccentHeight = 0.12,
		GuideAccentThickness = 0.1,
		GuideAccentColor = { 111, 222, 218 },
		SupportHeight = 1.06,
		SupportThickness = 0.42,
		SupportOffsetX = 2.9,
		SupportColor = { 69, 78, 87 },
		FrameHeight = 0.34,
		FrameCenterY = 0.83,
		FrameLengthPadding = 0.7,
		FrameWidthPadding = 1.0,
		FrameColor = { 84, 96, 106 },
		LabelHeight = 2.55,
		LabelWidthPixels = 128,
		LabelHeightPixels = 32,
		LabelTextSize = 16,
		LabelMaxDistance = 150,
		LabelColor = { 243, 249, 250 },
	},
	ConveyorItem = {
		Size = 1.0,
		LandingClearance = 0.08,
		DropStartHeight = 5.8,
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
