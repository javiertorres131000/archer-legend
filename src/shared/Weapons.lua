-- Weapons (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Weapons
-- Armas del jugador. Se eligen en el lobby (botón "Arma") y quedan guardadas en el perfil.
-- El servidor (Combat) decide todo; el cliente solo dibuja.
--
--   · Arco: el de siempre. Dispara de lejos con auto-apuntado; las habilidades de flechas
--     (flecha extra, abanico, perforación, rebote) cambian el disparo.
--   · Espada y puños (cuerpo a cuerpo): golpean a TODOS los enemigos dentro de un arco frente a
--     vos (Range en studs, Arc en grados). Pegan cuando un enemigo entra en alcance.
--     Las habilidades de flechas se convierten en algo útil para el cuerpo a cuerpo:
--       flecha extra → +MeleeBonus.FrontArrow de daño · par diagonal → +MeleeBonus.DiagonalArc°
--       de arco · perforación y rebote → +MeleeBonus.PierceRicochet de daño.
--     Críticos, quemadura, daño y cadencia funcionan igual que con el arco.
--
-- Campos: Id (no cambiar: se guarda en el perfil) · Name · Icon · Kind ("Ranged" | "Melee")
--   DamageMult: multiplica el daño · IntervalMult: multiplica el tiempo entre ataques
--   Range, Arc, Knockback: solo cuerpo a cuerpo · Description
--   Fx (opcional): estilo de efectos anime de Shared/FxStyles.lua (p. ej. "Frost"). Lo dibuja
--     Client/AnimeFx: tajo, Torbellino, Juicio, impactos y aura. Sin Fx: efectos simples.
--
-- Armas especiales (salen en la caja de armas, Shared/Crates.lua):
--   Base: el arma común de la que es variante ("Sword"). Juega como ella: mismas habilidades
--     (Torbellino, Juicio...), misma animación; pero con sus propios números (DamageMult, Range...)
--   Prize: Id del premio en Shared/CrateItems.lua que la desbloquea. Sin ese premio no se puede
--     elegir (lo revisa el servidor, WeaponService). Puede ser un arma de la caja de armas o un
--     personaje: la Espada Celestial viene con el skin Seraphiel.
--   Power (opcional): lo que HACE el arma además del daño (fuego, sangrado, rayos, grietas,
--     remate). Lo aplica Server/SkillEffects (ver la lista de campos ahí).
--   Tint (opcional): color de la hoja en primera persona si no hay modelo propio en
--     ReplicatedStorage > WeaponModels > <Id> (se usa el modelo de la Base teñido).

local Weapons = {}

Weapons.Default = "Bow"

Weapons.List = {
	{
		Id = "Bow",
		Name = "Arco",
		Icon = "🏹",
		Kind = "Ranged",
		DamageMult = 1,
		IntervalMult = 1,
		Description = "Dispara de lejos y apunta solo. Las habilidades de flechas mejoran el disparo.",
	},
	{
		Id = "Sword",
		Name = "Espada",
		Icon = "⚔️",
		Kind = "Melee",
		DamageMult = 1.3, -- más rápida que antes (era 1.9 cada 1.3): mismo daño por segundo
		IntervalMult = 0.9,
		Range = 11,
		Arc = 130,
		Knockback = 1.6,
		Description = "Tajo amplio frente a vos: pega fuerte a todos los que alcance. Hay que acercarse.",
	},
	{
		Id = "Fists",
		Name = "Puños",
		Icon = "👊",
		Kind = "Melee",
		DamageMult = 0.75,
		IntervalMult = 0.45,
		Range = 7,
		Arc = 80,
		Knockback = 0.7,
		Description = "Golpes muy rápidos y de corto alcance. Ideal con críticos y quemadura.",
	},

	-------------------------------------------------------------------
	-- Especiales (caja de armas)
	-------------------------------------------------------------------
	{
		Id = "FrostKatana",
		Name = "Katana de Escarcha",
		Icon = "🗡️",
		Kind = "Melee",
		Base = "Sword",
		Prize = "FrostKatana",
		Fx = "Frost",
		Tint = Color3.fromRGB(130, 215, 255),
		DamageMult = 2.15,
		IntervalMult = 1.2,
		Range = 12,
		Arc = 140,
		Knockback = 1.7,
		Power = { Color = Color3.fromRGB(130, 215, 255), Slow = 0.4, Finisher = { Kind = "Blast", Radius = 9, Ahead = 5, Mult = 1.4 } },
		Description = "Espada especial: cada tajo congela y frena un 40% a los enemigos; el remate (3er tajo) estalla en hielo.",
	},
	{
		Id = "InfernoBlade",
		Name = "Hoja Infernal",
		Icon = "🔥",
		Kind = "Melee",
		Base = "Sword",
		Prize = "InfernoBlade",
		Fx = "Inferno",
		Tint = Color3.fromRGB(255, 120, 40),
		DamageMult = 2.4,
		IntervalMult = 1.4,
		Range = 12.5,
		Arc = 150,
		Knockback = 2.2,
		Power = { Color = Color3.fromRGB(255, 120, 40), Burn = 0.35, Finisher = { Kind = "Blast", Radius = 10, Ahead = 6, Mult = 1.6 } },
		Description = "Espada especial: cada tajo prende fuego (35% del golpe por segundo, 3 s); el remate (3er tajo) es una explosión de fuego que quema todo alrededor.",
	},
	{
		Id = "CrimsonKatana",
		Name = "Katana Carmesí",
		Icon = "🩸",
		Kind = "Melee",
		Base = "Sword",
		Prize = "CrimsonKatana",
		Fx = "Crimson",
		Tint = Color3.fromRGB(230, 20, 45),
		DamageMult = 2.3,
		IntervalMult = 1.25,
		Range = 12.5,
		Arc = 150,
		Knockback = 2,
		Power = { Color = Color3.fromRGB(230, 20, 45), Bleed = 0.25, Finisher = { Kind = "Blast", Radius = 13, Ahead = 5, Mult = 2.2 } },
		Description = "Espada especial: cada tajo hace sangrar (25% por segundo, 3 s) y cada remate (3er tajo) explota en una esfera roja gigante que daña a todos.",
	},
	{
		Id = "VoidBow",
		Name = "Arco del Vacío",
		Icon = "🌀",
		Kind = "Ranged",
		Base = "Bow",
		Prize = "VoidBow",
		Fx = "Void",
		Tint = Color3.fromRGB(170, 85, 255),
		DamageMult = 1.6,
		IntervalMult = 1.15,
		PiercingEvery = 4,
		Power = { Color = Color3.fromRGB(170, 85, 255), Rift = { Radius = 5, Duration = 2.5, DpsMult = 0.3, Pull = 5, Max = 3 } },
		Description = "Cada flecha abre una grieta violeta que daña y atrae a los enemigos 2,5 s. Cada 4 disparos, una flecha perforante extra. Se obtiene en el Cofre de Armas.",
	},
	{
		Id = "CelestialBow",
		Name = "Arco Celestial",
		Icon = "⚡",
		Kind = "Ranged",
		Base = "Bow",
		Prize = "CelestialBow",
		Fx = "Celestial",
		Tint = Color3.fromRGB(255, 212, 110),
		DamageMult = 1.65,
		IntervalMult = 1.1,
		Power = { Color = Color3.fromRGB(255, 215, 110), ChainChance = 1, ChainTargets = 2, ChainMult = 0.35, StrikeEvery = 5, StrikeRadius = 7, StrikeMult = 1.5 },
		Description = "Cada flecha electrifica: el rayo salta a 2 enemigos cercanos. Cada 5 impactos cae un rayo del cielo que explota. Se obtiene en el Cofre de Armas.",
	},
	{
		Id = "CelestialSword",
		Name = "Espada Celestial",
		Icon = "✨",
		Kind = "Melee",
		Base = "Sword",
		Prize = "Seraphiel", -- viene con el skin Seraphiel (no sale en la caja de armas)
		Fx = "Celestial",
		Tint = Color3.fromRGB(255, 205, 90),
		DamageMult = 2.35,
		IntervalMult = 1.25,
		Range = 13,
		Arc = 150,
		Knockback = 2,
		Power = { Color = Color3.fromRGB(255, 215, 110), ChainChance = 0.35, ChainTargets = 3, ChainMult = 0.5, Finisher = { Kind = "Strike", Targets = 4, Range = 22, Mult = 1.8 } },
		Description = "La espada de Seraphiel: los tajos electrifican (35% de saltar a 3 enemigos) y el remate (3er tajo) hace caer rayos sobre 4 enemigos. Viene con el skin Seraphiel.",
	},
}

-- (Guanteletes Volcánicos: va al final de la lista para no mover los índices de las demás)
table.insert(Weapons.List, {
	Id = "VolcanicGauntlets",
	Name = "Guanteletes Volcánicos",
	Icon = "🌋",
	Kind = "Melee",
	Base = "Fists",
	Prize = "VolcanicGauntlets",
	Fx = "Inferno",
	Tint = Color3.fromRGB(255, 110, 30),
	DamageMult = 1.7,
	IntervalMult = 0.55,
	Range = 8.5,
	Arc = 100,
	Knockback = 1.2,
	-- Modelo: assets/weapons/VolcanicGauntlets (Blender) → ReplicatedStorage > WeaponModels > VolcanicGauntlets
	Power = { Color = Color3.fromRGB(255, 110, 30), Burn = 0.3, Finisher = { Kind = "Eruption", Every = 6, Radius = 11, Mult = 2 } },
	Description = "Puños de magma: cada golpe quema (30% por segundo, 3 s) y cada 6º golpe hace erupcionar el piso alrededor tuyo (radio 11, doble de daño) y quema todo. Se obtiene en el Cofre de Armas.",
})

-- ¿Este premio de las cajas desbloquea alguna arma? (las de la caja de armas y la de Seraphiel)
function Weapons.unlockedBy(prizeId: string): boolean
	for _, def in Weapons.List do
		if def.Prize == prizeId then
			return true
		end
	end
	return false
end

-- Qué dan las habilidades de flechas con un arma cuerpo a cuerpo
Weapons.MeleeBonus = {
	FrontArrow = 0.12, -- +12% de daño por cada flecha extra
	DiagonalArc = 20, -- +20° de arco por cada par diagonal
	PierceRicochet = 0.08, -- +8% de daño por cada perforación o rebote
}

Weapons.ById = {}
for _, def in Weapons.List do
	Weapons.ById[def.Id] = def
end

function Weapons.get(id: string?): any
	return Weapons.ById[id or Weapons.Default] or Weapons.ById[Weapons.Default]
end

-- Arma común con la que juega ("FrostKatana" → "Sword"; las comunes se devuelven a sí mismas)
function Weapons.baseOf(id: string?): string
	local def = Weapons.get(id)
	return def.Base or def.Id
end

-- ¿Hay que ganarla en una caja?
function Weapons.isSpecial(id: string?): boolean
	local def = type(id) == "string" and Weapons.ById[id] or nil
	return def ~= nil and def.Prize ~= nil
end

return Weapons
