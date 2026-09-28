--!strict

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
	:WaitForChild("Models")
	:WaitForChild("3D")
local AssetCatalog = require(Assets:WaitForChild("AssetCatalog"))

local AssetShowcaseService = {}
local started = false

local COLUMN_COUNT = 6
local CELL_SPACING = 20
local MAX_MODEL_EXTENT = 11
local GRID_CENTER = Vector3.new(-70, 0, 0)
local BASEPLATE_SIZE = Vector3.new(720, 4, 280)
local BASEPLATE_CENTER = Vector3.new(140, -2, 0)
local ASSET_LOAD_WORKERS = 3

local function createBaseplate(parent: Instance)
	local baseplate = Instance.new("Part")
	baseplate.Name = "GrassBaseplate"
	baseplate.Anchored = true
	baseplate.Size = BASEPLATE_SIZE
	baseplate.Position = BASEPLATE_CENTER
	baseplate.Material = Enum.Material.Grass
	baseplate.Color = Color3.fromRGB(114, 177, 82)
	baseplate.TopSurface = Enum.SurfaceType.Smooth
	baseplate.BottomSurface = Enum.SurfaceType.Smooth
	baseplate.Parent = parent
end

local function createSpawnPad(parent: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ShowcaseSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(15, 0.5, 12)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = Color3.fromRGB(151, 104, 65)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = parent
end

local function cellPosition(asset: any): Vector3
	local columnOffset = (asset.Column - (COLUMN_COUNT + 1) / 2) * CELL_SPACING
	local rowOffset = (asset.Row - (COLUMN_COUNT + 1) / 2) * CELL_SPACING
	return GRID_CENTER + Vector3.new(columnOffset, 0, rowOffset)
end

local function createLabel(parent: Instance, position: Vector3, asset: any)
	local anchor = Instance.new("Part")
	anchor.Name = asset.Key .. "_LabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Name = "AssetLabel"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.MaxDistance = 240
	gui.Size = UDim2.fromOffset(190, 42)
	gui.StudsOffset = Vector3.new(0, 0.4, 0)
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(43, 54, 37)
	label.BackgroundTransparency = 0.14
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s\nR%d · C%d", asset.DisplayName, asset.Row, asset.Column)
	label.TextColor3 = Color3.fromRGB(255, 255, 245)
	label.TextSize = 12
	label.TextWrapped = true
	label.Parent = gui
end

local function placeAsset(asset: any, parent: Instance): boolean
	if asset.AssetId <= 0 then
		warn("Tiny Factory 3D asset has not been imported yet: " .. asset.Key)
		return false
	end

	local ok, loadedAsset = pcall(function()
		return AssetService:LoadAssetAsync(asset.AssetId)
	end)
	if not ok then
		warn(
			"Tiny Factory could not load 3D asset "
				.. asset.Key
				.. " ("
				.. tostring(asset.AssetId)
				.. "): "
				.. tostring(loadedAsset)
		)
		return false
	end

	if not loadedAsset:IsA("Model") then
		warn("Tiny Factory imported 3D asset was not a Model: " .. asset.Key)
		loadedAsset:Destroy()
		return false
	end

	local model = loadedAsset :: Model
	local size = model:GetExtentsSize()
	local largestExtent = math.max(size.X, size.Y, size.Z)
	if largestExtent <= 0 then
		warn("Tiny Factory imported 3D asset has no measurable geometry: " .. asset.Key)
		model:Destroy()
		return false
	end

	model.Name = asset.Key
	model:SetAttribute("AssetKey", asset.Key)
	model:SetAttribute("SourceFile", asset.FileName)
	model:SetAttribute("SourceSha256", asset.SourceSha256)
	model:SetAttribute("RobloxAssetId", asset.AssetId)
	model:ScaleTo(MAX_MODEL_EXTENT / largestExtent)

	local partCount = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	if partCount ~= 1 then
		warn(string.format("Expected one mesh part for %s; imported %d parts.", asset.Key, partCount))
	end

	local target = cellPosition(asset)
	local pivot = model:GetPivot()
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local bottomOffset = (boundsCFrame.Position - pivot.Position).Y - boundsSize.Y / 2
	model:PivotTo(CFrame.new(target.X, bottomOffset * -1, target.Z) * pivot.Rotation)
	model.Parent = parent

	local finalBoundsCFrame, finalBoundsSize = model:GetBoundingBox()
	createLabel(
		parent,
		Vector3.new(target.X, finalBoundsCFrame.Position.Y + finalBoundsSize.Y / 2 + 2, target.Z),
		asset
	)
	return true
end

local function loadAssets(parent: Instance)
	local nextIndex = 1
	local loadedCount = 0
	local totalCount = #AssetCatalog
	local workerCount = math.min(ASSET_LOAD_WORKERS, totalCount)
	local workersFinished = 0

	for _ = 1, workerCount do
		task.spawn(function()
			while true do
				local asset = AssetCatalog[nextIndex]
				nextIndex += 1
				if not asset then
					break
				end

				local ok, didLoad = pcall(placeAsset, asset, parent)
				if ok and didLoad then
					loadedCount += 1
				elseif not ok then
					warn("Tiny Factory 3D asset showcase failed for " .. asset.Key .. ": " .. tostring(didLoad))
				end
			end
			workersFinished += 1
		end)
	end

	while workersFinished < workerCount do
		task.wait(0.1)
	end

	print(string.format("Tiny Factory 3D asset showcase loaded %d of %d assets.", loadedCount, totalCount))
end

function AssetShowcaseService.start()
	if started then
		return
	end
	started = true

	local existing = workspace:FindFirstChild("TinyFactory3DAssetShowcase")
	if existing then
		return
	end

	local showcase = Instance.new("Folder")
	showcase.Name = "TinyFactory3DAssetShowcase"
	showcase.Parent = workspace
	createBaseplate(showcase)
	createSpawnPad(showcase)

	local importedAssetCount = 0
	for _, asset in ipairs(AssetCatalog) do
		if asset.AssetId > 0 then
			importedAssetCount += 1
		end
	end
	if importedAssetCount == 0 then
		warn("Tiny Factory 3D assets are waiting for the main-only Roblox import workflow.")
		return
	end

	task.spawn(loadAssets, showcase)
end

return AssetShowcaseService
