--!strict
-- Exact original Figma rasters. Rectangles reproduce the image-fill transforms.
local UI = {}
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
-- Four immutable images per client, shared by every control. Roblox's legacy
-- Image property caches failed restricted-asset requests across play sessions.
-- ImageContent uses the authorized image directly without changing its pixels.
local images: { [string]: EditableImage } = {}
UI.Text = Color3.fromRGB(255, 237, 204)
UI.Muted = Color3.fromRGB(218, 187, 148)
UI.Panel = Color3.fromRGB(47, 38, 30)
UI.Assets = {
	Panel = { "rbxassetid://71291524765168", 316, 112, 300, 303 },
	Card = { "rbxassetid://71291524765168", 17, 651, 253, 333 },
	SelectedCard = { "rbxassetid://71291524765168", 270, 651, 247, 333 },
	Coins = { "rbxassetid://71291524765168", 267, 996, 248, 100 },
	Inventory = { "rbxassetid://71291524765168", 515, 996, 262, 100 },
	Roll = { "rbxassetid://137411904241513", 0, 0, 249, 138 },
	Action = { "rbxassetid://120956512848045", 10, 541, 260, 119 },
	Tab = { "rbxassetid://120956512848045", 272, 805, 244, 120 },
	SelectedTab = { "rbxassetid://120956512848045", 18, 805, 254, 120 },
	Coin = { "rbxassetid://91445651094912", 10, 146, 170, 176 },
	Dice = { "rbxassetid://91445651094912", 180, 146, 162, 176 },
	Chest = { "rbxassetid://91445651094912", 342, 146, 178, 176 },
	Settings = { "rbxassetid://91445651094912", 349, 911, 165, 166 },
	Close = { "rbxassetid://91445651094912", 16, 911, 169, 166 },
	Producer = { "rbxassetid://91445651094912", 10, 335, 175, 197 },
	Processor = { "rbxassetid://91445651094912", 185, 335, 157, 197 },
	Seller = { "rbxassetid://91445651094912", 342, 335, 181, 197 },
	Booster = { "rbxassetid://91445651094912", 523, 335, 158, 197 },
	Common = { "rbxassetid://91445651094912", 11, 1284, 176, 114 },
	Uncommon = { "rbxassetid://91445651094912", 187, 1284, 179, 114 },
	Rare = { "rbxassetid://91445651094912", 366, 1284, 171, 114 },
	Epic = { "rbxassetid://91445651094912", 537, 1284, 171, 114 },
	Legendary = { "rbxassetid://91445651094912", 708, 1284, 188, 114 },
}
function UI.asset(image: ImageLabel, key: string)
	local asset = UI.Assets[key]
	assert(asset, "Unknown Amber asset: " .. key)
	local uri = asset[1] :: string
	if not RunService:IsStudio() then
		image.Image = uri
		-- Pixel coordinates use the uploaded texture, not the original export size.
		local ratio = if key == "Roll" then Vector2.new(2, 2) else Vector2.new(682 / 1024, 1023 / 1536)
		image.ImageRectOffset = Vector2.new(math.round((asset[2] :: number) * ratio.X), math.round((asset[3] :: number) * ratio.Y))
		image.ImageRectSize = Vector2.new(math.round((asset[4] :: number) * ratio.X), math.round((asset[5] :: number) * ratio.Y))
		image:SetAttribute("AmberAsset", key)
		image:SetAttribute("AmberImageUri", uri)
		return
	end
	local source = images[uri]
	if not source then
		source = AssetService:CreateEditableImageAsync(Content.fromUri(uri))
		assert(source, "Could not load authorized Amber image: " .. key)
		images[uri] = source
	end
	image.ImageContent = Content.fromObject(source)
	-- Uploaded sheets are normalized to Roblox's maximum texture dimensions.
	local original = if key == "Roll" then Vector2.new(249, 138) else Vector2.new(1024, 1536)
	local ratio = source.Size / original
	image.ImageRectOffset = Vector2.new(math.round((asset[2] :: number) * ratio.X), math.round((asset[3] :: number) * ratio.Y))
	image.ImageRectSize = Vector2.new(math.round((asset[4] :: number) * ratio.X), math.round((asset[5] :: number) * ratio.Y))
	image:SetAttribute("AmberImageUri", uri)
	image:SetAttribute("AmberAsset", key)
end
function UI.image(parent: Instance, key: string): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = key .. "Artwork"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	UI.asset(image, key)
	image.Parent = parent
	return image
end
function UI.skin(parent: GuiObject, key: string): ImageLabel
	parent.BackgroundTransparency = 1
	parent.BorderSizePixel = 0
	local image = UI.image(parent, key)
	image.Name = "AmberBackground"
	image.ScaleType = Enum.ScaleType.Stretch
	image.ZIndex = 0
	return image
end
function UI.label(parent: Instance, name: string, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = UI.Text
	label.TextSize = 18
	label.TextWrapped = true
	label.Parent = parent
	return label
end
-- Caption spacing must not pad the button's background image or hit target.
function UI.caption(button: TextButton, left: number)
	button.TextTransparency = 1
	local caption = UI.label(button, "Caption", button.Text)
	caption.Position = UDim2.fromScale(left, 0)
	caption.Size = UDim2.fromScale(1 - left - 0.08, 1)
	caption.ZIndex = 2
	local function sync()
		caption.Text = button.Text
		caption.TextSize = button.TextSize
		caption.TextColor3 = button.TextColor3
	end
	for _, property in ipairs({ "Text", "TextSize", "TextColor3" }) do
		button:GetPropertyChangedSignal(property):Connect(sync)
	end
	sync()
end
return UI
