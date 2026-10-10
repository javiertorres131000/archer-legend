-- Objetos temporales: nunca se escriben en Profiles.
local Rarities = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Rarities"))
local Items = {}
Items.List = {
	{ Id = "SwiftBoots", Name = "Botas del viento", Rarity = "Common", Max = 5, Description = "+8% de velocidad por copia." },
	{ Id = "MagnetStone", Name = "Piedra imán", Rarity = "Common", Max = 5, Description = "+20% de alcance de recogida por copia." },
	{ Id = "Heart", Name = "Corazón de roble", Rarity = "Uncommon", Max = 5, Description = "+10 de vida y cura 10 por copia." },
	{ Id = "Fang", Name = "Colmillo salvaje", Rarity = "Uncommon", Max = 5, Description = "+8% de daño por copia." },
	{ Id = "Ember", Name = "Ascua viva", Rarity = "Rare", Max = 4, Description = "Aura de fuego cercana. Más copias: más alcance y daño." },
	{ Id = "Storm", Name = "Bobina de tormenta", Rarity = "Epic", Max = 3, Description = "Un rayo salta entre enemigos cada 3 segundos." },
	{ Id = "Powder", Name = "Pólvora encantada", Rarity = "Rare", Max = 4, Description = "Tus bajas explotan. El fuego aumenta la explosión." },
	{ Id = "Lens", Name = "Lente del cazador", Rarity = "Rare", Max = 4, Description = "+4% de crítico por copia." },
	{ Id = "Hourglass", Name = "Reloj del vendaval", Rarity = "Legendary", Max = 2, Description = "Reduce 20% la recarga del dash y 8% el intervalo de disparo." },
	{ Id = "Prism", Name = "Prisma infinito", Rarity = "Mythic", Max = 1, Description = "Duplica aura y rayos. Sus bajas también explotan. Arcoíris." },
}
Items.ById = {}
for _, def in Items.List do Items.ById[def.Id] = def end
function Items.roll(stacks, rarity)
	local pool = {}
	for _, def in Items.List do
		if (stacks[def.Id] or 0) < def.Max and (not rarity or def.Rarity == rarity) then table.insert(pool, def) end
	end
	if #pool == 0 and rarity then return Items.roll(stacks) end
	if #pool == 0 then return nil end
	local total = 0
	for _, def in pool do total += Rarities.Weights[def.Rarity] end
	local roll = math.random() * total
	for _, def in pool do
		roll -= Rarities.Weights[def.Rarity]
		if roll <= 0 then return def end
	end
	return pool[#pool]
end
function Items.apply(stats, id)
	if id == "SwiftBoots" then stats.walkSpeed *= 1.08
	elseif id == "MagnetStone" then stats.pickupRadius *= 1.2
	elseif id == "Heart" then stats.maxHealth += 10
	elseif id == "Fang" then stats.damage *= 1.08
	elseif id == "Lens" then stats.critChance = math.min(0.8, stats.critChance + 0.04)
	elseif id == "Hourglass" then stats.dashCooldown *= 0.8; stats.attackInterval *= 0.92 end
end
return Items
