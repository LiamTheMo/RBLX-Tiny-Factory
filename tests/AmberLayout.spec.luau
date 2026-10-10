local Layout = require("../src/shared/AmberLayout")
for _, size in ipairs({{1672,884},{1366,710},{1920,1022},{874,344},{667,317},{320,568},{390,786}}) do
 local w,h = size[1],size[2]
 local m = Layout.measure(w,h)
 assert(m.PanelWidth <= w and m.PanelHeight > 0 and m.PanelTop + m.PanelHeight <= h)
 local rollLeft,rollRight = m.RollCenter-m.RollWidth/2,m.RollCenter+m.RollWidth/2
 assert(rollLeft >= m.InventoryWidth+12, "bottom controls overlap")
 assert(rollRight <= w, "roll escapes viewport")
 assert(m.RollHeight >= 44 and m.InventoryHeight >= 44)
 if m.Landscape then assert(rollRight < w-m.PanelWidth, "roll overlaps inventory panel") end
end
print("AmberLayout: desktop and compact safe-area geometry passed")
