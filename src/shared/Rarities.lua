-- Rareza común a habilidades, objetos, cofres y equipo.
local Rarities = {}
Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
Rarities.Names = { Common = "Común", Uncommon = "Poco común", Rare = "Rara", Epic = "Épica", Legendary = "Legendaria", Mythic = "Mítica" }
Rarities.Colors = {
	Common = Color3.fromRGB(180, 185, 195), Uncommon = Color3.fromRGB(95, 220, 125),
	Rare = Color3.fromRGB(75, 160, 255), Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 190, 60), Mythic = Color3.fromRGB(255, 100, 190),
}
Rarities.Weights = { Common = 48, Uncommon = 27, Rare = 16, Epic = 7, Legendary = 1.8, Mythic = 0.2 }
function Rarities.index(id)
	return table.find(Rarities.Order, id)
end
function Rarities.roll()
	local roll = math.random() * 100
	for _, id in Rarities.Order do
		roll -= Rarities.Weights[id]
		if roll <= 0 then return id end
	end
	return "Mythic"
end
function Rarities.color(id, now)
	if id == "Mythic" then return Color3.fromHSV((now or 0) * 0.18 % 1, 0.75, 1) end
	return Rarities.Colors[id] or Rarities.Colors.Common
end
return Rarities
