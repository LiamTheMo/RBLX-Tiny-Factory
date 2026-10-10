--!strict
-- Measures the usable ScreenGui area, after Roblox's safe-area insets.
local Layout = {}
function Layout.measure(width: number, height: number)
	local compact = width < 900 or height < 600
	local landscape = compact and width > height
	local scale = if compact then 1 else math.min(width / 1672, height / 884)
	local panelWidth = if compact then (if landscape then math.min(440, width * 0.46) else width - 16) else 650 * scale
	local top = if compact then (if landscape then 8 else 76) else 40 * scale
	local bottom = if compact then (if landscape then 8 else 100) else 46 * scale
	local panelHeight = math.min(760 * scale, height - top - bottom)
	local hudScale = if compact then 0.60 else scale
	local inventoryWidth = if compact and not landscape then math.min(150, width * 0.4) else 262 * hudScale
	local availableDockWidth = if landscape then width - panelWidth - inventoryWidth - 40 else width - inventoryWidth - 36
	local rollWidth = if compact then math.min(220, availableDockWidth) else 440 * hudScale
	return {
		Compact = compact, Landscape = landscape, Scale = scale,
		PanelWidth = panelWidth, PanelHeight = panelHeight, PanelTop = top,
		Columns = if landscape then 1 elseif compact then 2 else 3,
		CoinWidth = 257 * hudScale, CoinHeight = 100 * hudScale,
		InventoryWidth = inventoryWidth, InventoryHeight = 100 * hudScale,
		RollWidth = rollWidth, RollHeight = if compact then math.max(70, rollWidth * 170 / 440) else 170 * hudScale,
		RollCenter = if landscape then inventoryWidth + 28 + rollWidth / 2 elseif compact then width - rollWidth / 2 - 8 else width * 0.46,
		SettingsX = if landscape then 257 * hudScale + 24 else width - 64 * hudScale - 12,
		SettingsSize = 64 * hudScale,
	}
end
return Layout
