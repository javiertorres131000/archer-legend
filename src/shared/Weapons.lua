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
		DamageMult = 1.9,
		IntervalMult = 1.3,
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
}

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

return Weapons
