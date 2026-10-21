-- Synergies (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Synergies
-- Pares de habilidades que combinan bien. Cuando completás un par en la partida aparece el
-- cartel "¡SINERGIA!" con el nombre del combo y su bono, y el servidor aplica el bono
-- (una vez por partida y por par, Progression.grant).
--
-- Para agregar una: { A = "IdHabilidad", B = "IdHabilidad", Name = "Nombre", Bonus = "texto",
-- Apply = function(s) ... end }. Los Id están en Shared/Skills.lua. Las dos tienen que poder
-- salir con la misma arma (comunes o del mismo mazo); test_dopamine.luau lo revisa.
-- Apply recibe las stats del jugador (Server/PlayerData.newStats) y las mejora.

local Synergies = {}

Synergies.List = {
	-- Comunes (cualquier arma)
	{ A = "Crit", B = "CritDamage", Name = "Golpe letal", Bonus = "+5% de crítico", Apply = function(s) s.critChance += 0.05 end },
	{ A = "Fire", B = "AttackSpeed", Name = "Infierno", Bonus = "La quemadura hace +50%", Apply = function(s) s.burnBonus += 0.5 end },
	{ A = "Damage", B = "CritDamage", Name = "Fuerza bruta", Bonus = "+10% de daño", Apply = function(s) s.damage *= 1.1 end },
	{ A = "Thunder", B = "Crit", Name = "Tormenta eléctrica", Bonus = "+10% de rayo en cadena", Apply = function(s) s.chainChance += 0.1 end },
	{ A = "Vampirism", B = "Vitality", Name = "Sangre eterna", Bonus = "+1 de vida por muerte", Apply = function(s) s.lifeOnKill += 1 end },
	{ A = "Explosive", B = "Thunder", Name = "Reacción en cadena", Bonus = "Explosiones +3 studs de radio", Apply = function(s) s.explodeRadius += 3 end },
	{ A = "Frost", B = "Explosive", Name = "Escarcha volátil", Bonus = "Explosiones +20% de daño", Apply = function(s) s.explodeOnKill += 0.2 end },
	{ A = "ManaShield", B = "Dodge", Name = "Intocable", Bonus = "El escudo se recarga 3 s antes", Apply = function(s) s.shieldInterval = math.max(4, s.shieldInterval - 3) end },
	-- 🏹 Arco
	{ A = "Pierce", B = "Ricochet", Name = "Flecha imparable", Bonus = "+1 rebote", Apply = function(s) s.ricochet += 1 end },
	{ A = "FrontArrow", B = "Diagonal", Name = "Lluvia de puntas", Bonus = "+10% de daño", Apply = function(s) s.damage *= 1.1 end },
	{ A = "ChargedShot", B = "Pierce", Name = "Arpón", Bonus = "Tiro cargado cada 3 disparos", Apply = function(s) s.chargedEvery = 3 end },
	{ A = "HunterEye", B = "Crit", Name = "Francotirador", Bonus = "+25% de daño a lejanos", Apply = function(s) s.farDamage += 0.25 end },
	{ A = "BackArrow", B = "Diagonal", Name = "Erizo", Bonus = "+1 flecha trasera", Apply = function(s) s.backArrows += 1 end },
	{ A = "ExplosiveArrow", B = "Diagonal", Name = "Bombardeo", Bonus = "Explosiones +20% de daño", Apply = function(s) s.explosiveArrow += 0.2 end },
	{ A = "DoubleShot", B = "FrontArrow", Name = "Ráfaga gemela", Bonus = "+8% de cadencia", Apply = function(s) s.attackInterval *= 0.92 end },
	{ A = "FirstStrike", B = "HunterEye", Name = "Cazador paciente", Bonus = "Primera sangre +30%", Apply = function(s) s.firstStrike += 0.3 end },
	{ A = "PhantomArrow", B = "Pierce", Name = "Espectro", Bonus = "Flecha fantasma cada 2 s", Apply = function(s) s.phantomInterval = 2 end },
	-- ⚔️ Espada
	{ A = "WideBlade", B = "LongBlade", Name = "Mandoble", Bonus = "+10° de arco y +1 de alcance", Apply = function(s) s.meleeArc += 10; s.meleeRange += 1 end },
	{ A = "Whirlwind", B = "WideBlade", Name = "Tornado de acero", Bonus = "Torbellino cada 4 golpes", Apply = function(s) s.whirlEvery = 4 end },
	{ A = "Execute", B = "Bloodlust", Name = "Verdugo", Bonus = "Ejecución +30%", Apply = function(s) s.executeBonus += 0.3 end },
	{ A = "SlashWave", B = "LongBlade", Name = "Ola de acero", Bonus = "Onda cada 3 tajos", Apply = function(s) s.slashWaveEvery = 3 end },
	{ A = "Riposte", B = "KnightArmor", Name = "Venganza", Bonus = "Contraataque +50%", Apply = function(s) s.riposte += 0.5 end },
	{ A = "DeepWound", B = "Execute", Name = "Hemorragia", Bonus = "Sangrado +25%", Apply = function(s) s.bleed += 0.25 end },
	-- 👊 Puños
	{ A = "Combo", B = "AttackSpeed", Name = "Ametralladora", Bonus = "+8% de cadencia", Apply = function(s) s.attackInterval *= 0.92 end },
	{ A = "Uppercut", B = "Combo", Name = "Campeón de boxeo", Bonus = "Combo +2% por golpe", Apply = function(s) s.comboStep += 0.02 end },
	{ A = "SwiftFeet", B = "Uppercut", Name = "Peso pluma", Bonus = "+5% de velocidad", Apply = function(s) s.walkSpeed *= 1.05 end },
	{ A = "Shockwave", B = "Uppercut", Name = "Terremoto", Bonus = "Golpe sísmico +4 studs", Apply = function(s) s.shockRadius += 4 end },
	{ A = "Adrenaline", B = "Combo", Name = "Furia", Bonus = "Adrenalina +15%", Apply = function(s) s.adrenaline += 0.15 end },
	{ A = "DoubleHit", B = "AttackSpeed", Name = "Mil golpes", Bonus = "+10% de doble golpe", Apply = function(s) s.doubleHit += 0.1 end },
}

-- Sinergias que completa la habilidad nueva `newId` con las que ya tenés (`owned`: id → niveles).
-- `shown` (opcional): las que ya se avisaron en esta partida, para no repetirlas. Las claves
-- pueden ser la sinergia (tabla) o su nombre.
function Synergies.completedBy(newId: string, owned: { [string]: number }, shown: { [any]: boolean }?): { any }
	local list = {}
	for _, syn in Synergies.List do
		local other = if syn.A == newId then syn.B elseif syn.B == newId then syn.A else nil
		if other and (owned[other] or 0) > 0 and not (shown and (shown[syn] or shown[syn.Name])) then
			table.insert(list, syn)
		end
	end
	return list
end

return Synergies
