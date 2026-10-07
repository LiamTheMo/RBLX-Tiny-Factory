--!strict

-- Display only: currency calculations and saved values remain numeric.
local NumberFormatter = {}
local suffixes = { "", "k", "m", "b", "t", "qd", "qt", "sx", "sp", "oc", "no", "dc" }
local units = { "u", "d", "t", "qd", "qt", "sx", "sp", "oc", "no" }
local tens = { "dc", "vg", "tg", "qag", "qig", "sxg", "spg", "ocg", "nog" }
for illion = 11, 99 do
	local unit = illion % 10
	table.insert(suffixes, (if unit == 0 then "" else units[unit]) .. tens[math.floor(illion / 10)])
end
table.insert(suffixes, "ct") -- centillion, 10^303; covers every finite double.
NumberFormatter.Suffixes = table.freeze(suffixes)

function NumberFormatter.format(value: number): string
	if value ~= value then return "0.00" end
	if value == math.huge then return "∞" end
	if value == -math.huge then return "-∞" end
	local sign = if value < 0 then "-" else ""
	local scaled = math.abs(value)
	local tier = 1
	while scaled >= 1000 and tier < #suffixes do
		scaled /= 1000
		tier += 1
	end
	-- Promote after rounding too: 999.999k is 1.00m, never 1000.00k.
	if scaled >= 999.995 and tier < #suffixes then
		scaled /= 1000
		tier += 1
	end
	if scaled < 0.005 then sign = "" end
	return sign .. string.format("%.2f", scaled) .. suffixes[tier]
end

function NumberFormatter.integer(value: number): string
	if value == value and math.abs(value) < 1000 then
		return string.format("%.0f", value)
	end
	return NumberFormatter.format(value)
end

return table.freeze(NumberFormatter)
