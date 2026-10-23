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
--   Ultimate (opcional): habilidad definitiva con cinemática (ver Server/UltimateService).
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
		Ultimate = {
			Name = "Cero Absoluto", Style = "Frost", Color = Color3.fromRGB(135, 225, 255),
			ChargeHits = 45, Duration = 3.2, FirstAt = 0.5, FinalAt = 2.3,
			Column = false, Radius = 23, TargetRange = 65, Mult = 12, BossMult = 0.5,
			Slow = 0.7,
			Steps = { "1 · CONCENTRAR EL FRÍO", "2 · CORTE GLACIAL", "3 · CERO ABSOLUTO" },
		},
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
		Ultimate = {
			Name = "Tierra Quemada",
			TargetRange = 65,
			Style = "Inferno",
			Color = Color3.fromRGB(255, 110, 20),
			ChargeHits = 45,
			Duration = 3.2,
			FirstAt = 0.5,
			FirstFrac = 0.1,
			FinalAt = 2.4,
			Column = false,
			Radius = 22,
			Mult = 12,
			BossMult = 0.5,
			Steps = { "1 · CARGA INFERNAL", "2 · EL SUELO ARDE", "3 · TIERRA QUEMADA" },
		},
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
		-- Definitiva (Server/UltimateService + Client/UltimateFx): se carga con 45 golpes, tecla Q
		Ultimate = {
			Name = "Luna Sangrienta",
			Color = Color3.fromRGB(235, 25, 50),
			ChargeHits = 45,
			Duration = 3.2,
			-- Iaido: se agacha, cruza en zigzag a los enemigos de la zona dejando cortes colgados en
			-- el aire, vuelve, enfunda y todos los cortes estallan a la vez
			FirstAt = 0.6, -- empieza el corte relámpago (daño chico a todos los de la zona)
			FirstFrac = 0.1,
			FinalAt = 2.6, -- enfunda: estallan los cortes
			Column = false, -- sin columna de energía (tiene su propio final)
			Radius = 24,
			Mult = 14, -- × tu daño × el DamageMult del arma
			BossMult = 0.5,
			Bleed = 0.3,
			Steps = {
				"1 · IAI: te agachás bajo la luna de sangre",
				"2 · CORTE RELÁMPAGO: cruzás a todos los enemigos",
				"3 · ENFUNDAR: todos los cortes estallan a la vez",
			},
		},
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
		-- Definitiva: flecha oscura que abre un agujero negro donde apuntás; atrae y daña a todos
		Ultimate = {
			Name = "Horizonte de Sucesos",
			Style = "Void",
			Color = Color3.fromRGB(170, 85, 255),
			ChargeHits = 40,
			Duration = 3.4,
			FirstAt = 0.35, -- flecha al cielo; un cometa cae en el punto
			Step2At = 0.7,
			BlackHole = { Distance = 32, From = 0.7, To = 2.7, Every = 0.2, Pull = 3, Frac = 0.04 },
			FinalAt = 2.8, -- implosión
			Column = false, -- el final es la implosión del agujero
			Radius = 28,
			Mult = 13,
			BossMult = 0.5,
			Steps = {
				"1 · FLECHA DEL VACÍO: al cielo, y cae donde apuntás",
				"2 · AGUJERO NEGRO: lo sostenés con la mano; atrae y daña a todos",
				"3 · IMPLOSIÓN: cerrás el puño y explota",
			},
		},
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
		-- Definitiva: carga una flecha gigante de luz y dispara un láser en línea recta
		Ultimate = {
			Name = "Juicio Celestial",
			Color = Color3.fromRGB(255, 215, 110),
			ChargeHits = 40,
			Duration = 3.2,
			FirstAt = 0.5, -- aparece la flecha gigante
			FinalAt = 2.6, -- el disparo
			Line = { Length = 90, Width = 6 }, -- franja que barre: 90 studs de largo, 12 de ancho
			Radius = 26, -- (solo para la distancia de los efectos)
			Mult = 16, -- × tu daño × el DamageMult del arma, a todos los de la línea
			BossMult = 0.5,
			Steps = {
				"1 · CARGA: la luz se junta en tu arco",
				"2 · FLECHA GIGANTE: apuntá hacia donde mirás",
				"3 · ¡DISPARO! Un rayo en línea recta que atraviesa todo",
			},
		},
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
		-- Definitiva: salta girando en círculo, llama a la tormenta y cae con un rayo gigante
		Ultimate = {
			Name = "Ira del Serafín",
			Style = "Celestial",
			Color = Color3.fromRGB(255, 215, 110),
			ChargeHits = 45,
			Duration = 3.2,
			Leap = { Height = 18 }, -- salta girando y flota hasta el golpe final
			FirstAt = 0.5, -- la espada apunta al cielo (onda chica alrededor)
			FirstFrac = 0.08,
			Bolts = { From = 0.9, To = 2.4, Every = 0.25, Targets = 3, Frac = 0.16 }, -- tormenta
			GiantBolt = true, -- el golpe final es un rayo gigante con un círculo de rayos
			FinalAt = 2.6,
			Radius = 24,
			Mult = 14,
			BossMult = 0.5,
			Steps = {
				"1 · SALTO: subís girando y la espada llama a la tormenta",
				"2 · TORMENTA: rayos sobre cada enemigo",
				"3 · IRA DEL SERAFÍN: caés con un rayo gigante",
			},
		},
		Description = "La espada de Seraphiel: los tajos electrifican (35% de saltar a 3 enemigos) y el remate (3er tajo) hace caer rayos sobre 4 enemigos. Viene con el skin Seraphiel.",
	},
}

-- (Guanteletes Volcánicos: va al final de la lista para no mover los índices de las demás)
table.insert(Weapons.List, {
	Id = "VolcanicGauntlets",
	Ultimate = {
		Name = "Falla Volcánica", Style = "Volcanic", Color = Color3.fromRGB(255, 95, 20),
		ChargeHits = 45, Duration = 3.2, FirstAt = 0.5, FinalAt = 2.3,
		Column = false, Radius = 21, TargetRange = 60, Mult = 11, BossMult = 0.5,
		Burn = 0.2,
		Steps = { "1 · CARGAR LOS PUÑOS", "2 · ROMPER EL SUELO", "3 · FALLA VOLCÁNICA" },
	},
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
	if def.Ultimate then
		def.Ultimate.TargetRange = def.Ultimate.TargetRange or (if def.Ultimate.Line then def.Ultimate.Line.Length else 65)
	end
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
