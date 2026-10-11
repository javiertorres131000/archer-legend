--!strict
-- TalentService (ModuleScript)
-- Ubicación: ServerScriptService > Server > TalentService
-- Árbol de talentos permanente (catálogo y reglas en Shared/Talents.lua). Se guarda en el perfil
-- (Profiles: Data.Talents[Id] = rango) y se aplica al empezar cada partida.
--
-- El cliente pide por Remotes.TalentRequest:
--   ("Get")         → niveles actuales
--   ("Buy", Id)     → sube un rango. El servidor valida: perfil cargado, en el lobby (no listo ni en
--                     partida), frecuencia, Id, conexión con un nodo que ya tenés, máximo, puntos
--                     (nivel de cuenta), oro y gemas — con Talents.check, la misma regla que dibuja
--                     el cliente. Cobro y subida van juntos, sin pausas (una sola transacción).
--   ("Reset")       → vacía el árbol: devuelve los puntos, NO el oro ni las gemas.
-- Responde con Remotes.TalentState: (niveles, mensaje).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Talents = require(Shared:WaitForChild("Talents"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)

local TalentService = {}

local remotes: any = nil
local lastRequest: { [Player]: number } = {}

-- Manda al cliente sus niveles (una copia) y un mensaje opcional.
function TalentService.publish(player: Player, message: string?)
	local data = Profiles.get(player)
	if not data or not remotes then
		return
	end
	remotes.TalentState:FireClient(player, data.Talents, message)
end

-- Revisa lo común a comprar y reiniciar. Devuelve (datos, motivo).
local function guard(player: Player): (any, string?)
	local data = Profiles.get(player)
	if not data then
		return nil, "El perfil sigue cargando."
	end
	local state = PlayerData.get(player)
	if not state or state.inMatch or player:GetAttribute("Ready") == true then
		return nil, "Cancelá LISTO para cambiar talentos."
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.25 then
		return nil, "Esperá un momento."
	end
	lastRequest[player] = now
	return data, nil
end

-- Sube un rango. Devuelve (ok, mensaje).
function TalentService.buy(player: Player, id: any): (boolean, string)
	local data, problem = guard(player)
	if not data then
		return false, problem or ""
	end
	local check = Talents.check(data.Talents, data.Account.Level, data.Currencies, id)
	if not check.ok then
		return false, check.reason or "No se puede."
	end
	local def = Talents.ById[id]
	local rank = (data.Talents[id] or 0) + 1
	-- Sin yields entre la validación y el cobro
	data.Talents[id] = rank
	Profiles.addCurrency(player, "Gold", -check.gold)
	if check.gems > 0 then
		Profiles.addCurrency(player, "Gems", -check.gems)
	end
	Profiles.refresh(player)
	Profiles.saveSoon(player)
	return true, if def.Max > 1 then string.format("%s rango %d", def.Name, rank) else def.Name .. " desbloqueado"
end

-- Vacía el árbol. Los puntos vuelven; el oro y las gemas gastados no.
function TalentService.reset(player: Player): (boolean, string)
	local data, problem = guard(player)
	if not data then
		return false, problem or ""
	end
	if next(data.Talents) == nil then
		return false, "El árbol ya está vacío."
	end
	data.Talents = {}
	Profiles.refresh(player)
	Profiles.saveSoon(player)
	return true, "Árbol reiniciado: recuperaste todos tus puntos."
end

-- Suma el árbol del jugador a las stats de la partida (una vez, al empezar). Va en el orden del
-- catálogo para que el resultado no dependa del orden de la tabla guardada.
function TalentService.apply(player: Player, stats: any)
	local data = Profiles.get(player)
	if not data then
		return
	end
	for _, def in Talents.List do
		local level = data.Talents[def.Id] or 0
		if level > 0 then
			def.Apply(stats, math.min(level, def.Max))
		end
	end
end

function TalentService.init(r: any)
	remotes = r
	Profiles.onLoaded(function(player)
		TalentService.publish(player)
	end)
	r.TalentRequest.OnServerEvent:Connect(function(player: Player, action: any, arg: any)
		if action == "Get" then
			TalentService.publish(player)
		elseif action == "Buy" or action == "Reset" then
			local ok, message
			if action == "Buy" then
				ok, message = TalentService.buy(player, arg)
			else
				ok, message = TalentService.reset(player)
			end
			TalentService.publish(player, (if ok then "✔ " else "") .. message)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return TalentService
