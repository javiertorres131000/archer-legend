-- CombatText (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > CombatText
-- Dibuja los números flotantes que manda el servidor (Remotes.CombatText, ver CombatFeed):
--   · daño que hacés: número blanco sobre el enemigo (grande y amarillo si es un golpe fuerte)
--   · crítico: número amarillo enorme con "!"
--   · quemadura: naranja · daño de compañeros (opcional): gris
--   · daño que recibís: número rojo que sube desde tu barra de vida
--   · XP: "+5 XP" celeste al juntar orbes
--   · botín: monedas y gemas que saltan del enemigo y vuelan hacia vos, con "+3 💰"
-- Es solo visual: no cambia nada del juego.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatText = remotes:WaitForChild("CombatText") :: RemoteEvent

local player = Players.LocalPlayer
local LIFETIME = Config.CombatText.Lifetime
local BIG_HIT = 40 -- desde este daño el número sale grande y amarillo

local currencyInfo = {}
for _, c in Currencies do
	currencyInfo[c.Id] = c
end

---------------------------------------------------------------------
-- Números en el mundo (sobre los enemigos)
---------------------------------------------------------------------
type Popup = {
	attachment: Attachment,
	gui: BillboardGui,
	label: TextLabel,
	born: number,
	life: number,
	rise: number,
	jitter: number,
	size: number,
	active: boolean,
}

local pool: { Popup } = {}
local POOL_SIZE = 48

for i = 1, POOL_SIZE do
	local attachment = Instance.new("Attachment")
	attachment.Name = "CombatText"
	attachment.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = attachment
	gui.Enabled = false
	gui.Parent = attachment
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = gui
	pool[i] = {
		attachment = attachment,
		gui = gui,
		label = label,
		born = 0,
		life = LIFETIME,
		rise = 3,
		jitter = 0,
		size = 24,
		active = false,
	}
end

local nextSlot = 1
local function popup(pos: Vector3, text: string, color: Color3, size: number, rise: number, life: number?)
	-- Toma el siguiente del pool (si están todos ocupados, reusa el más viejo)
	local p = pool[nextSlot]
	nextSlot = nextSlot % POOL_SIZE + 1
	p.attachment.WorldPosition = pos
	p.label.Text = text
	p.label.TextColor3 = color
	p.label.TextTransparency = 0
	p.label.TextStrokeTransparency = 0
	p.size = size
	p.rise = rise
	p.life = life or LIFETIME
	p.jitter = (math.random() - 0.5) * 2.5
	p.born = os.clock()
	p.active = true
	p.gui.Enabled = true
end

---------------------------------------------------------------------
-- Daño recibido (en pantalla, sobre la barra de vida)
---------------------------------------------------------------------
local screen = Instance.new("ScreenGui")
screen.Name = "CombatText"
screen.ResetOnSpawn = false
screen.DisplayOrder = 4
screen.Parent = player:WaitForChild("PlayerGui")

type HurtLabel = { label: TextLabel, born: number, x: number, active: boolean }
local hurtPool: { HurtLabel } = {}
for i = 1, 10 do
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = UDim2.fromOffset(120, 40)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 70, 60)
	label.TextStrokeTransparency = 0
	label.TextSize = 30
	label.Visible = false
	label.Parent = screen
	hurtPool[i] = { label = label, born = 0, x = 0, active = false }
end
local nextHurt = 1
local function hurt(amount: number)
	local h = hurtPool[nextHurt]
	nextHurt = nextHurt % #hurtPool + 1
	h.label.Text = "-" .. tostring(amount)
	h.label.TextSize = math.clamp(26 + amount * 0.6, 26, 48)
	h.x = (math.random() - 0.5) * 140
	h.born = os.clock()
	h.active = true
	h.label.Visible = true
end

---------------------------------------------------------------------
-- Monedas que vuelan hacia el jugador
---------------------------------------------------------------------
type Coin = { part: Part, from: Vector3, burst: Vector3, born: number }
local coins: { Coin } = {}
local coinFolder = Instance.new("Folder")
coinFolder.Name = "LootVisuals"
coinFolder.Parent = workspace
local COIN_TIME = 0.75

local function spawnCoins(pos: Vector3, id: string, count: number)
	local info = currencyInfo[id]
	for _ = 1, math.min(count, 6) do
		local part = Instance.new("Part")
		part.Shape = if id == "Gold" then Enum.PartType.Cylinder else Enum.PartType.Ball
		part.Size = if id == "Gold" then Vector3.new(0.2, 0.9, 0.9) else Vector3.new(0.8, 0.8, 0.8)
		part.Material = Enum.Material.Neon
		part.Color = info and info.Color or Color3.new(1, 1, 1)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Position = pos
		part.Parent = coinFolder
		local angle = math.random() * math.pi * 2
		table.insert(coins, {
			part = part,
			from = pos,
			burst = Vector3.new(math.cos(angle) * 3, 4 + math.random() * 2, math.sin(angle) * 3),
			born = os.clock() + math.random() * 0.12,
		})
	end
end

---------------------------------------------------------------------
-- Eventos del servidor
---------------------------------------------------------------------
combatText.OnClientEvent:Connect(function(events)
	if typeof(events) ~= "table" then
		return
	end
	for _, e in events do
		local kind, pos, amount = e.k, e.p, e.a
		if kind == "hurt" and typeof(amount) == "number" then
			hurt(amount)
		elseif typeof(pos) ~= "Vector3" then
			continue
		elseif kind == "hit" and typeof(amount) == "number" then
			local big = amount >= BIG_HIT
			popup(
				pos + Vector3.new(0, 2, 0),
				tostring(amount),
				if big then Color3.fromRGB(255, 225, 80) else Color3.new(1, 1, 1),
				if big then 34 else 26,
				3
			)
		elseif kind == "crit" and typeof(amount) == "number" then
			popup(pos + Vector3.new(0, 2.5, 0), tostring(amount) .. "!", Color3.fromRGB(255, 200, 40), 40, 4, LIFETIME * 1.2)
		elseif kind == "burn" and typeof(amount) == "number" then
			popup(pos + Vector3.new(0, 1.5, 0), tostring(amount), Color3.fromRGB(255, 150, 40), 20, 2.5)
		elseif kind == "poison" and typeof(amount) == "number" then
			popup(pos + Vector3.new(0, 1.5, 0), tostring(amount), Color3.fromRGB(120, 230, 70), 20, 2.5)
		elseif kind == "ally" and typeof(amount) == "number" then
			popup(pos + Vector3.new(0, 2, 0), tostring(amount), Color3.fromRGB(180, 180, 195), 18, 2.5)
		elseif kind == "xp" and typeof(amount) == "number" then
			popup(pos + Vector3.new(0, 3.5, 0), "+" .. amount .. " XP", Color3.fromRGB(120, 220, 255), 22, 3, LIFETIME * 1.3)
		elseif kind == "loot" and typeof(e.g) == "table" then
			local parts = {}
			for _, c in Currencies do
				local n = e.g[c.Id]
				if typeof(n) == "number" and n > 0 then
					table.insert(parts, string.format("+%d %s", n, c.Icon))
					spawnCoins(pos + Vector3.new(0, 1, 0), c.Id, n)
				end
			end
			if #parts > 0 then
				popup(pos + Vector3.new(0, 5, 0), table.concat(parts, "  "), Color3.fromRGB(246, 208, 122), 22, 2.5, LIFETIME * 1.5)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Animación (cada frame)
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local now = os.clock()

	for _, p in pool do
		if p.active then
			local age = now - p.born
			local t = age / p.life
			if t >= 1 then
				p.active = false
				p.gui.Enabled = false
			else
				-- Sale grande, se achica rápido y sube mientras se desvanece
				local pop = 1 + 0.5 * math.max(0, 1 - age / 0.12)
				p.label.TextSize = math.floor(p.size * pop)
				p.gui.StudsOffsetWorldSpace = Vector3.new(p.jitter * 0.4, p.rise * t, 0)
				local fade = math.clamp((t - 0.55) / 0.45, 0, 1)
				p.label.TextTransparency = fade
				p.label.TextStrokeTransparency = fade
			end
		end
	end

	for _, h in hurtPool do
		if h.active then
			local t = (now - h.born) / LIFETIME
			if t >= 1 then
				h.active = false
				h.label.Visible = false
			else
				h.label.Position = UDim2.new(0.5, h.x, 1, -40 - 60 * t)
				local fade = math.clamp((t - 0.5) / 0.5, 0, 1)
				h.label.TextTransparency = fade
				h.label.TextStrokeTransparency = fade
			end
		end
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for i = #coins, 1, -1 do
		local c = coins[i]
		local t = (now - c.born) / COIN_TIME
		if t >= 1 or not root then
			c.part:Destroy()
			table.remove(coins, i)
		elseif t > 0 then
			-- Primero saltan hacia afuera y después vuelan a tu personaje
			local target = (root :: BasePart).Position
			local burst = c.from + c.burst * math.sin(math.min(t, 0.5) * math.pi)
			local k = math.clamp((t - 0.35) / 0.65, 0, 1)
			k = k * k
			c.part.Position = burst:Lerp(target, k)
			c.part.CFrame = CFrame.new(c.part.Position) * CFrame.Angles(0, now * 8, math.rad(90))
		end
	end
end)
