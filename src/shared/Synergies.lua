-- Synergies (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Synergies
-- Pares de habilidades que combinan bien. Cuando completás un par en la partida, aparece el
-- cartel "¡SINERGIA!" con el nombre del combo (una vez por partida y por par).
-- Por ahora es solo un aviso: no da ningún bono extra (el efecto ya viene de las dos habilidades).
--
-- Para agregar una: { A = "IdHabilidad", B = "IdHabilidad", Name = "Nombre del combo" }.
-- Los Id están en Shared/Skills.lua. Las dos tienen que poder salir con la misma arma
-- (comunes o del mismo mazo); test_dopamine.luau lo revisa.

local Synergies = {}

Synergies.List = {
	-- Comunes (cualquier arma)
	{ A = "Crit", B = "CritDamage", Name = "Golpe letal" },
	{ A = "Fire", B = "AttackSpeed", Name = "Infierno" },
	{ A = "Damage", B = "CritDamage", Name = "Fuerza bruta" },
	-- 🏹 Arco
	{ A = "Pierce", B = "Ricochet", Name = "Flecha imparable" },
	{ A = "FrontArrow", B = "Diagonal", Name = "Lluvia de puntas" },
	{ A = "ChargedShot", B = "Pierce", Name = "Arpón" },
	{ A = "HunterEye", B = "Crit", Name = "Francotirador" },
	{ A = "BackArrow", B = "Diagonal", Name = "Erizo" },
	-- ⚔️ Espada
	{ A = "WideBlade", B = "LongBlade", Name = "Mandoble" },
	{ A = "Whirlwind", B = "WideBlade", Name = "Tornado de acero" },
	{ A = "Execute", B = "Bloodlust", Name = "Verdugo" },
	-- 👊 Puños
	{ A = "Combo", B = "AttackSpeed", Name = "Ametralladora" },
	{ A = "Uppercut", B = "Combo", Name = "Campeón de boxeo" },
	{ A = "SwiftFeet", B = "Uppercut", Name = "Peso pluma" },
}

-- Sinergias que completa la habilidad nueva `newId` con las que ya tenés (`owned`: id → niveles).
-- `shown` (opcional): las que ya se avisaron en esta partida, para no repetirlas.
function Synergies.completedBy(newId: string, owned: { [string]: number }, shown: { [any]: boolean }?): { any }
	local list = {}
	for _, syn in Synergies.List do
		local other = if syn.A == newId then syn.B elseif syn.B == newId then syn.A else nil
		if other and (owned[other] or 0) > 0 and not (shown and shown[syn]) then
			table.insert(list, syn)
		end
	end
	return list
end

return Synergies
