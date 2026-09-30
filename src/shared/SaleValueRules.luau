--!strict

export type ModifierLayer = {
	AdditiveBonus: number?,
	Multiplier: number?,
}

local SaleValueRules = {}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function readAdditiveBonus(layer: any, maximum: number): number
	if type(layer) ~= "table" or not isFiniteNumber(layer.AdditiveBonus) then
		return 0
	end
	return math.clamp(layer.AdditiveBonus, 0, maximum)
end

local function readMultiplier(layer: any, maximum: number): number
	if type(layer) ~= "table" or not isFiniteNumber(layer.Multiplier) or layer.Multiplier <= 0 then
		return 1
	end
	return math.clamp(layer.Multiplier, 0.01, maximum)
end

function SaleValueRules.calculate(
	baseValue: any,
	typeModifiers: ModifierLayer?,
	buffModifiers: ModifierLayer?,
	sellerModifiers: ModifierLayer?,
	maxValue: any
): number?
	if not isFiniteNumber(baseValue) or baseValue < 0 or not isFiniteNumber(maxValue) or maxValue < 1 then
		return nil
	end

	local maximum = math.floor(maxValue)
	local additiveValue = math.min(baseValue, maximum)
	local totalMultiplier = 1

	local function applyLayer(layer: ModifierLayer?)
		additiveValue = math.min(maximum, additiveValue + readAdditiveBonus(layer, maximum))
		totalMultiplier = math.min(maximum, totalMultiplier * readMultiplier(layer, maximum))
	end

	applyLayer(typeModifiers)
	applyLayer(buffModifiers)
	applyLayer(sellerModifiers)

	local result = additiveValue * totalMultiplier
	if not isFiniteNumber(result) or result >= maximum then
		return maximum
	end
	return math.max(1, math.floor(result))
end

return SaleValueRules
