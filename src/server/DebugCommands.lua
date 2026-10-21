--!strict
-- DebugCommands (ModuleScript)
-- Ubicación: ServerScriptService > Server > DebugCommands
-- Comandos de prueba para el panel F2 (DebugPanel en el cliente). Sirven para probar rápido sin
-- pegar código en la barra de comandos.
--
-- Seguridad: el cliente solo pide ("acción"). El servidor decide si ese jugador puede:
--   Config.Debug.Commands activo Y (estamos en Studio O su UserId está en Config.Debug.Admins).
-- En un servidor publicado sin admins, nadie puede usarlos aunque mande el pedido a mano.
-- Al que puede, se le marca el atributo "DebugAllowed" para que el cliente muestre el panel.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Talents = require(Shared:WaitForChild("Talents"))
local RunItemDefs = require(Shared:WaitForChild("RunItems"))
local Remotes = require(script.Parent.Remotes)
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)
local Waves = require(script.Parent.Waves)
local Enemies = require(script.Parent.Enemies)
local Progression = require(script.Parent.Progression)
local ItemService = require(script.Parent.ItemService)
local ChapterUnlocks = require(script.Parent.ChapterUnlocks)
local TalentService = require(script.Parent.TalentService)
local Run = require(script.Parent.Run)
local RunLog = require(script.Parent.RunLog)
local WeaponService = require(script.Parent.WeaponService)
local Weapons = require(Shared:WaitForChild("Weapons"))
local WaveEvents = require(script.Parent.WaveEvents)
local MasteryService = require(script.Parent.MasteryService)
local Mastery = require(Shared:WaitForChild("Mastery"))
local CrateEquip = require(script.Parent.CrateEquip)

local DebugCommands = {}

local lastRequest: { [Player]: number } = {}

function DebugCommands.allowed(player: Player): boolean
	if not Config.Debug.Commands then
		return false
	end
	return RunService:IsStudio() or table.find(Config.Debug.Admins, player.UserId) ~= nil
end

local function inMatch(player: Player): boolean
	local state = PlayerData.get(player)
	return state ~= nil and state.inMatch and Run.isActive()
end

-- Cada acción devuelve (ok, mensaje). Las de partida solo andan con una partida en curso.
local Actions: { [string]: { label: string, match: boolean?, run: (Player) -> (boolean, string) } } = {
	Gold = { label = "+5000 oro", run = function(p)
		return Profiles.addCurrency(p, "Gold", 5000), "+5000 oro"
	end },
	Gems = { label = "+500 gemas", run = function(p)
		return Profiles.addCurrency(p, "Gems", 500), "+500 gemas"
	end },
	Stones = { label = "+50 piedras", run = function(p)
		return Profiles.addCurrency(p, "Stones", 50), "+50 piedras"
	end },
	Levels = { label = "+5 niveles de cuenta", run = function(p)
		local data = Profiles.get(p)
		if not data then
			return false, "Perfil sin cargar"
		end
		local xp = 0
		for i = 0, 4 do
			xp += Talents.xpNeeded(data.Account.Level + i)
		end
		Profiles.addAccountXP(p, xp - data.Account.XP)
		TalentService.publish(p)
		return true, "Nivel de cuenta " .. data.Account.Level
	end },
	Chapters = { label = "Desbloquear capítulos", run = function(p)
		if not Profiles.get(p) then
			return false, "Perfil sin cargar"
		end
		for _, ch in Chapters do
			local rec = Profiles.chapter(p, ch.Id)
			if rec then
				rec.Unlocked = true
			end
		end
		ChapterUnlocks.refresh(p)
		Profiles.saveSoon(p)
		return true, "Capítulos desbloqueados (queda guardado)"
	end },
	Demon = { label = "Darme y equipar Demonio Ígneo", run = function(p)
		local data = Profiles.get(p)
		if not data then
			return false, "Perfil sin cargar"
		end
		data.Crates.Owned.FireDemon = math.max(data.Crates.Owned.FireDemon or 0, 1)
		data.Crates.Equipped.Character = "FireDemon"
		CrateEquip.publish(p)
		Profiles.saveSoon(p)
		task.spawn(CrateEquip.refreshLook, p)
		return true, "Demonio Ígneo equipado (queda guardado)"
	end },
	Report = { label = "Resumen de partidas", run = function(_p)
		local text = RunLog.report(7)
		return true, text
	end },
	SkipWave = { label = "Saltar oleada", match = true, run = function(_p)
		Waves.debugSkip()
		return true, "Oleada terminada"
	end },
	KillAll = { label = "Matar enemigos", match = true, run = function(_p)
		local n = 0
		for _, e: any in table.clone(Enemies.list) do
			if e.alive then
				if e.hidden then
					Enemies.setHidden(e, false)
				end
				Enemies.damage(e, e.health, nil, "debug")
				n += 1
			end
		end
		return true, n .. " enemigos"
	end },
	Boss = { label = "Aparecer jefe", match = true, run = function(p)
		local ch = Run.currentChapter() -- capítulo, piso de la torre o desafío del día
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not ch or not ch.Boss or not root then
			return false, "Sin jefe o sin personaje"
		end
		local pos = Enemies.findSpawnPosition(PlayerData.getAliveTargets()) or (root.Position + Vector3.new(0, 0, 25))
		Enemies.spawn(ch.Boss.Type, pos, { healthMult = ch.HealthMult, dmgMult = ch.DamageMult })
		return true, "Jefe: " .. ch.Boss.Type
	end },
	LevelUp = { label = "Subir de nivel (partida)", match = true, run = function(_p)
		local gs = Remotes.GameState
		Progression.addXP(math.max(1, (gs:GetAttribute("XPNeeded") or 1) - (gs:GetAttribute("XP") or 0)))
		return true, "Nivel " .. Progression.level()
	end },
	Item = { label = "Objeto al azar", match = true, run = function(p)
		local state = PlayerData.get(p)
		local pool = {}
		for _, def in RunItemDefs.List do
			if state and (state.items[def.Id] or 0) < def.Max then
				table.insert(pool, def.Id)
			end
		end
		if #pool == 0 then
			return false, "Ya tenés todos al máximo"
		end
		local id = pool[math.random(#pool)]
		return ItemService.grant(p, id), "Objeto: " .. id
	end },
	Heal = { label = "Curarme", match = true, run = function(p)
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return false, "No estás en pie"
		end
		humanoid.Health = humanoid.MaxHealth
		return true, "Vida al máximo"
	end },
	-- Te da todas las armas especiales (como si salieran de la caja de armas) y queda guardado
	Weapons = { label = "Todas las armas especiales", run = function(p)
		local data = Profiles.get(p)
		if not data then
			return false, "Perfil sin cargar"
		end
		local n = 0
		for _, w in Weapons.List do
			if w.Prize and (data.Crates.Owned[w.Prize] or 0) <= 0 then
				data.Crates.Owned[w.Prize] = 1
				n += 1
			end
		end
		WeaponService.publish(p)
		Profiles.saveSoon(p)
		return true, n .. " armas nuevas (elegilas en ⚔️ Arma)"
	end },
	-- Solo visual (no hace daño): para ver los efectos del arma sin esperar a que salgan
	FxWhirl = { label = "Efecto: Torbellino", match = true, run = function(p)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false, "Sin personaje"
		end
		Remotes.MeleeSwing:FireAllClients(p.UserId, root.Position, root.CFrame.LookVector, 11, 360, p:GetAttribute("Weapon"))
		return true, "Torbellino (solo visual)"
	end },
	Elite = { label = "Aparecer élite", match = true, run = function(p)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local ch = Run.currentChapter()
		if not root or not ch then
			return false, "Sin personaje"
		end
		local types = WaveEvents.hordeTypes(ch, Waves.current())
		local affixes = Config.Events.Elite.Affixes
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		local e = Enemies.spawn(types[2], root.Position + look * 20, { healthMult = ch.HealthMult, dmgMult = ch.DamageMult, elite = affixes[math.random(1, #affixes)] })
		WaveEvents.onEliteSpawned(e)
		return true, "Élite: " .. tostring(e.eliteName)
	end },
	Horde = { label = "Momento horda", match = true, run = function(_p)
		WaveEvents.debugHorde(Run.currentChapter())
		return true, "¡Horda!"
	end },
	Goal = { label = "Meta de equipo", match = true, run = function(_p)
		WaveEvents.debugGoal(PlayerData.getAliveTargets())
		local g = WaveEvents.goal()
		return true, if g then g.text else "Sin meta"
	end },
	Mastery = { label = "+1 nivel de maestría (arma elegida)", run = function(p)
		local data = Profiles.get(p)
		if not data then
			return false, "Perfil cargando"
		end
		local family = MasteryService.familyOf(data.Weapon)
		local xp = data.Mastery[family] or 0
		local level = Mastery.levelOf(xp)
		data.Mastery[family] = Mastery.Levels[math.min(level + 1, Mastery.MaxLevel)]
		MasteryService.publish(p)
		Profiles.saveSoon(p)
		return true, string.format("Maestría de %s: nivel %d", Mastery.FamilyNames[family], Mastery.levelOf(data.Mastery[family]))
	end },
	FxJudgment = { label = "Efecto: Juicio", match = true, run = function(p)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false, "Sin personaje"
		end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		Remotes.MeleeSwing:FireAllClients(p.UserId, root.Position + look * 14, Vector3.zAxis, 10, 360, "Judgment")
		return true, "Juicio (solo visual)"
	end },
}
DebugCommands.Actions = Actions

-- Orden en el panel
DebugCommands.Order = { "Gold", "Gems", "Stones", "Levels", "Chapters", "Weapons", "Demon", "Report", "SkipWave", "KillAll", "Boss", "LevelUp", "Item", "Heal", "Elite", "Horde", "Goal", "Mastery", "FxWhirl", "FxJudgment" }

function DebugCommands.run(player: Player, action: any): (boolean, string)
	if not DebugCommands.allowed(player) then
		return false, "Sin permiso"
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.2 then
		return false, "Esperá un momento"
	end
	lastRequest[player] = now
	local def = if type(action) == "string" then Actions[action] else nil
	if not def then
		return false, "Comando inválido"
	end
	if def.match and not inMatch(player) then
		return false, "Solo durante una partida"
	end
	local ok, message = def.run(player)
	print(string.format("[Debug] %s → %s: %s", player.Name, action, message))
	return ok, message
end

function DebugCommands.init()
	local function mark(player: Player)
		if DebugCommands.allowed(player) then
			local list = {}
			for _, id in DebugCommands.Order do
				table.insert(list, id .. "=" .. Actions[id].label)
			end
			player:SetAttribute("DebugAllowed", table.concat(list, ";"))
		end
	end
	for _, p in Players:GetPlayers() do
		mark(p)
	end
	Players.PlayerAdded:Connect(mark)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, action: any)
		if not DebugCommands.allowed(player) then
			return -- ni respuesta: el pedido se ignora
		end
		local ok, message = DebugCommands.run(player, action)
		Remotes.DebugCommand:FireClient(player, ok, message)
	end)
end

return DebugCommands
