--!strict

export type CubeTypeDefinition = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	ValueMultiplier: number,
	Color: { number },
}

local types: { [string]: CubeTypeDefinition } = {
	Standard = { Id = "Standard", DisplayName = "Standard", Rarity = "Common", ValueMultiplier = 1, Color = { 244, 217, 158 } },
	Wet = { Id = "Wet", DisplayName = "Wet", Rarity = "Uncommon", ValueMultiplier = 1.15, Color = { 80, 190, 235 } },
	Air = { Id = "Air", DisplayName = "Air", Rarity = "Uncommon", ValueMultiplier = 1.1, Color = { 185, 235, 255 } },
	Nature = { Id = "Nature", DisplayName = "Nature", Rarity = "Uncommon", ValueMultiplier = 1.2, Color = { 104, 200, 105 } },
	Earth = { Id = "Earth", DisplayName = "Earth", Rarity = "Uncommon", ValueMultiplier = 1.25, Color = { 177, 126, 74 } },
	Fire = { Id = "Fire", DisplayName = "Fire", Rarity = "Rare", ValueMultiplier = 1.35, Color = { 255, 126, 55 } },
	Ice = { Id = "Ice", DisplayName = "Ice", Rarity = "Rare", ValueMultiplier = 1.35, Color = { 135, 220, 255 } },
	Metal = { Id = "Metal", DisplayName = "Metal", Rarity = "Rare", ValueMultiplier = 1.3, Color = { 165, 180, 195 } },
	Lightning = { Id = "Lightning", DisplayName = "Lightning", Rarity = "Rare", ValueMultiplier = 1.4, Color = { 255, 225, 65 } },
	Light = { Id = "Light", DisplayName = "Light", Rarity = "Epic", ValueMultiplier = 1.5, Color = { 255, 245, 155 } },
	Shadow = { Id = "Shadow", DisplayName = "Shadow", Rarity = "Epic", ValueMultiplier = 1.55, Color = { 130, 100, 185 } },
	Time = { Id = "Time", DisplayName = "Time", Rarity = "Epic", ValueMultiplier = 1.8, Color = { 95, 225, 200 } },
	Crystal = { Id = "Crystal", DisplayName = "Crystal", Rarity = "Epic", ValueMultiplier = 1.9, Color = { 115, 210, 230 } },
	Rainbow = { Id = "Rainbow", DisplayName = "Rainbow", Rarity = "Legendary", ValueMultiplier = 2.5, Color = { 255, 130, 220 } },
}

local CubeTypeDefinitions = {}

function CubeTypeDefinitions.get(typeId: string): CubeTypeDefinition?
	return types[typeId]
end

function CubeTypeDefinitions.all(): { [string]: CubeTypeDefinition }
	return types
end

return CubeTypeDefinitions
