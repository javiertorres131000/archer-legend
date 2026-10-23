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
		Description = "Espada especial: llamas de hielo en cada tajo. Juega como la espada, pero pega más fuerte y más rápido.",
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
		Description = "Espada especial: fuego en cada tajo. Más lenta que la Katana de Escarcha, pero cada golpe pega más y llega más lejos.",
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
		Description = "Espada especial: un aura carmesí te envuelve y cada remate explota en una esfera roja gigante.",
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
		Description = "La espada de Seraphiel: tajos de luz dorada de largo alcance. Viene con el skin Seraphiel.",
	},
}

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
