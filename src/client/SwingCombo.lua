-- SwingCombo (ModuleScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > SwingCombo
-- Combo de 3 tajos de las armas con estilo anime (Fx en Shared/Weapons.lua). Lleva, por jugador,
-- en qué paso del combo va cada golpe que avisa el servidor (Remotes.MeleeSwing) y cuánto dura,
-- para que todo lo que se dibuja de ese golpe coincida: el arma en primera persona (WeaponFx),
-- el tajo y el impacto (AnimeFx) y el cuerpo y la cámara (HeldWeapon).
--   paso 1: diagonal de arriba a la derecha hacia abajo a la izquierda, con estocada
--   paso 2: diagonal de vuelta, de abajo a la izquierda hacia arriba a la derecha
--   paso 3: remate: se agacha, salta y baja la hoja de arriba hacia abajo
-- Si pasa más de RESET segundos sin golpear, vuelve al paso 1. El Torbellino (360°) no avanza.
--
-- Tiempos (estilo anime: carga larga, golpe casi instantáneo, pose congelada):
--   wind   = fracción en la que termina la carga y arranca el golpe
--   strike = fracción en la que el golpe ya llegó al final
--   hold   = fracción hasta la que queda congelado en la pose final (después vuelve)
-- Si el jugador ataca más rápido de lo que dura el movimiento, todo se comprime para terminar
-- antes del golpe siguiente.
--
-- Este módulo se conecta al aviso apenas se carga, así que corre antes que los scripts que lo
-- usan (se conectan después de requerirlo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MeleeSwing") :: RemoteEvent

local SwingCombo = {}

SwingCombo.RESET = 1.2

export type Move = { dur: number, wind: number, strike: number, hold: number }
SwingCombo.Moves = {
	{ dur = 0.5, wind = 0.28, strike = 0.36, hold = 0.8 },
	{ dur = 0.5, wind = 0.28, strike = 0.36, hold = 0.8 },
	{ dur = 0.64, wind = 0.42, strike = 0.5, hold = 0.84 },
} :: { Move }
SwingCombo.Spin = { dur = 0.56, wind = 0.15, strike = 0.85, hold = 0.85 } :: Move

type State = { step: number, at: number, gap: number?, spinAt: number?, spinGap: number? }
local states: { [number]: State } = {}

remote.OnClientEvent:Connect(function(userId, _origin, _dir, _range, arc, weaponId)
	if type(userId) ~= "number" or weaponId == "Judgment" or weaponId == "Rain" or weaponId == "Burst" then
		return
	end
	local now = os.clock()
	local s = states[userId]
	if arc == 360 then
		if not s then
			s = { step = 0, at = -math.huge }
			states[userId] = s
		end
		s.spinGap = if s.spinAt then now - s.spinAt else nil
		s.spinAt = now
		return
	end
	if not s or now - s.at > SwingCombo.RESET then
		s = { step = 0, at = now, gap = nil }
		states[userId] = s
	else
		s.gap = now - s.at
	end
	s.step = s.step % 3 + 1
	s.at = now
end)

-- Paso del último golpe de ese jugador (1, 2 o 3)
function SwingCombo.step(userId: number): number
	local s = states[userId]
	return if s then s.step else 1
end

-- Duración real del último golpe (comprimida si ataca más rápido que la animación)
function SwingCombo.duration(userId: number, step: number): number
	local m = SwingCombo.Moves[step] or SwingCombo.Moves[1]
	local s = states[userId]
	local gap = s and s.gap
	if gap and gap * 0.95 < m.dur then
		return math.max(gap * 0.95, 0.18)
	end
	return m.dur
end

-- Duración del Torbellino (comprimida si los giros salen muy seguidos)
function SwingCombo.spinDuration(userId: number): number
	local s = states[userId]
	local gap = s and s.spinGap
	if gap and gap * 0.95 < SwingCombo.Spin.dur then
		return math.max(gap * 0.95, 0.25)
	end
	return SwingCombo.Spin.dur
end

-- Segundos desde el aviso hasta que el golpe arranca (cuando sale el tajo)
function SwingCombo.strikeDelay(userId: number, step: number): number
	local m = SwingCombo.Moves[step] or SwingCombo.Moves[1]
	return SwingCombo.duration(userId, step) * m.wind
end

-- Hacia dónde barre: -1 = de derecha a izquierda (o de arriba a abajo), +1 = al revés
function SwingCombo.side(step: number): number
	return if step == 2 then 1 else -1
end

-- Inclinación del tajo (grados, sobre el eje de la mirada): diagonales y el remate casi vertical
function SwingCombo.tilt(step: number): number
	if step == 3 then
		return 80
	end
	return 30
end

return SwingCombo
