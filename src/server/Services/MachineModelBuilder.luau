--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Visuals = require(Shared.MachineVisualConfig)
local Geometry = require(Shared.FactoryItemGeometry)
local Builder = {}

local function rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

function Builder.build(parent: Instance, origin: Vector3, slot: number, definition: any): (Model, Part, Part?)
	local profileKey = definition.VisualStyle or (if definition.Category == "Producer" then "Dropper" else definition.Category)
	local profile = Visuals.Profiles[profileKey] or Visuals.Profiles.Processor
	local variant = Visuals.Variants[definition.Id] or {}
	local primary = rgb(variant.PrimaryColor or profile.PrimaryColor)
	local accent = rgb(variant.AccentColor or profile.AccentColor)
	local base = origin + Vector3.new((slot - 1) * Visuals.SlotPitch, Geometry.machineLift(), 0)
	local model = Instance.new("Model")
	model.Name = string.format("Slot_%d_%s", slot, definition.Id)
	model:SetAttribute("MachineId", definition.Id)
	model:SetAttribute("VisualVariant", definition.Id)
	model.Parent = parent
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Anchored = true
		result.CanCollide = false
		result.Material = Enum.Material.SmoothPlastic
		result.Size = size
		result.Position = base + offset
		result.Color = color
		result.TopSurface = Enum.SurfaceType.Smooth
		result.BottomSurface = Enum.SurfaceType.Smooth
		result.Parent = model
		return result
	end
	local housing: Part
	local hitbox: Part? = nil
	if profile.Style == "Dropper" then
		local width = variant.WidthScale or 1
		part("DropperFoot", Vector3.new(2.8, 0.3, 2.4), Vector3.new(0, 0.32, 0), accent)
		for _, side in ipairs({ -1, 1 }) do
			part("DropperSupport", Vector3.new(0.3, 2.2, 0.3), Vector3.new(0, 1.4, side * 0.86), accent)
			part("DropperHead", Vector3.new(0.62 * width, 1.2, 1.8), Vector3.new(side * 0.78 * width, 2.55, 0), primary)
			part("DropperNozzle", Vector3.new(0.18, 0.5, 0.18), Vector3.new(side * 0.48, 1.65, 0), accent)
		end
		for _, side in ipairs({ -1, 1 }) do
			part("DropperNozzleSide", Vector3.new(0.18, 0.5, 0.18), Vector3.new(0, 1.65, side * 0.48), accent)
		end
		housing = part("DropperHousing", Vector3.new(2.2 * width, 0.35, 2.0), Vector3.new(0, 3.25, 0), primary)
	elseif profile.Style == "Seller" then
		part("SellerFoot", Vector3.new(2.8, 0.3, 2.4), Vector3.new(0, 0.32, 0), primary)
		part("SellerTray", Vector3.new(2.4, 0.2, 2.1), Vector3.new(0, 0.36, 0), accent)
		for _, side in ipairs({ -1, 1 }) do
			part("SellerDoorPillar", Vector3.new(0.35, 2.2, 0.4), Vector3.new(0, 1.55, side * 1.25), primary)
		end
		housing = part("SellerHousing", Vector3.new(1.5, 0.35, 2.9), Vector3.new(0, 2.75, 0), primary)
		local box = Visuals.SellerHitbox
		hitbox = part("SellerHitbox", Vector3.new(table.unpack(box.Size)), Vector3.new(table.unpack(box.Offset)), primary)
		hitbox.Transparency = 1
		hitbox.CanTouch = false
		hitbox.CanQuery = false
		hitbox.CastShadow = false
	else
		part("ProcessorFoot", Vector3.new(2.8, 0.3, 2.4), Vector3.new(0, 0.32, 0), accent)
		housing = part("ProcessorHousing", Vector3.new(2.1, 1.5, 1.9), Vector3.new(0, 1.25, 0), primary)
	end
	for _, detail in ipairs(variant.Parts or {}) do
		local extra = part(detail.Name, Vector3.new(table.unpack(detail.Size)), Vector3.new(table.unpack(detail.Offset)), accent)
		if detail.Shape == "Ball" then extra.Shape = Enum.PartType.Ball end
		if detail.Shape == "Cylinder" then extra.Shape = Enum.PartType.Cylinder end
		local rotation = detail.Rotation
		if rotation then extra.CFrame *= CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3])) end
	end
	local badgeY = if profile.Style == "Dropper" then 2.7 elseif profile.Style == "Seller" then 2.65 else 1.25
	local badgeZ = if profile.Style == "Seller" then -1.5 else -1.1
	local identityPlate = part("IdentityPlate", Vector3.new(0.8, 0.65, 0.12), Vector3.new(0, badgeY, badgeZ), primary)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local badge = Instance.new("SurfaceGui")
		badge.Name = "MachineBadge"
		badge.Face = face
		badge.CanvasSize = Vector2.new(160, 130)
		badge.Parent = identityPlate
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.Text = variant.Symbol or "•"
		icon.TextColor3 = accent
		icon.TextStrokeColor3 = Color3.fromRGB(35, 38, 42)
		icon.TextStrokeTransparency = 0.25
		icon.Font = Enum.Font.GothamBlack
		icon.TextSize = 56
		icon.Parent = badge
	end
	return model, housing, hitbox
end

return Builder
