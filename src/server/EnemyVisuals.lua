-- EnemyVisuals (ModuleScript)
-- Ubicación: ServerScriptService > Server > EnemyVisuals
-- Cómo se ve cada enemigo. La caja de colisión (el Part que mueve Enemies) no cambia: esto solo
-- le suelda algo encima.
--
--   · Con modelo: se busca en ServerStorage > EnemyModels, en este orden:
--       1. <Id del tipo>  (p. ej. "GreenSlime"): solo para ese enemigo
--       2. "Redondos"     : para todos los enemigos redondos (slimes, murciélagos, bombas...)
--       3. "Todos"        : para cualquier enemigo que no tenga uno propio
--     Cada uno puede ser un Model o una Folder con varios Models: en ese caso cada tipo de
--     enemigo usa siempre el mismo modelo de la carpeta (variedad entre tipos, coherencia en
--     cada tipo). Además el modelo se tiñe con el color del enemigo (Config.Enemy.ModelTint).
--     El modelo se clona,
--     se escala a la altura del enemigo, se apoya en el piso y se suelda a la caja, que queda
--     invisible. Los scripts del modelo se BORRAN al clonarlo (los modelos gratis de la Caja de
--     herramientas a veces traen scripts maliciosos). Si el modelo trae un AnimationController o
--     Humanoid con una Animation llamada "Walk" (o "Idle"), se reproduce en bucle.
--   · Sin modelo: la figura de siempre con ojos (Config.Enemy.Eyes), para que se lea hacia dónde
--     mira y tenga algo de personalidad.
--
-- Avisos: el parpadeo de "va a atacar" y la quemadura cambian el color de la caja. Con modelo, la
-- caja es invisible, así que se muestran con un Highlight mientras dure (Roblox dibuja hasta 31
-- a la vez: alcanza porque son momentáneos). Los dorados llevan uno fijo.

local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local EnemyCfg = Config.Enemy

local EnemyVisuals = {}

export type Visual = {
	model: Model?,
	parts: { BasePart },
	base: { [BasePart]: number }, -- transparencia original de cada pieza
	hitboxVisible: boolean, -- false con modelo: la caja nunca se ve
	highlight: Highlight?,
	tinted: boolean,
	alpha: number,
}

local function modelsFolder(): Instance?
	return ServerStorage:FindFirstChild(EnemyCfg.ModelsFolder or "EnemyModels")
end

-- Número estable a partir del Id (el mismo tipo elige siempre el mismo modelo de una carpeta)
local function hash(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1000003
	end
	return h
end

-- Una entrada puede ser un Model o una carpeta con varios Models
local function pick(entry: Instance?, typeId: string): Instance?
	if not entry or entry:IsA("Model") then
		return entry
	end
	local models = {}
	for _, child in entry:GetChildren() do
		if child:IsA("Model") then
			table.insert(models, child)
		end
	end
	table.sort(models, function(a, b)
		return a.Name < b.Name
	end)
	return if #models > 0 then models[hash(typeId) % #models + 1] else nil
end

-- Qué modelo le toca a un tipo (ver arriba). shape: "Ball" para los redondos.
local function templateFor(folder: Instance, typeId: string, shape: string?): Instance?
	return pick(folder:FindFirstChild(typeId), typeId)
		or (if shape == "Ball" then pick(folder:FindFirstChild("Redondos"), typeId) else nil)
		or pick(folder:FindFirstChild("Todos"), typeId)
end
EnemyVisuals.templateFor = templateFor

-- Saca scripts y cualquier cosa que pueda ejecutar código o pesar de más.
function EnemyVisuals.sanitize(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
end

-- Lista de tipos sin modelo (para avisar en la Salida, una vez).
function EnemyVisuals.missing(typeIds: { string }, shapeOf: ((string) -> string?)?): { string }
	local folder = modelsFolder()
	local out = {}
	if not folder then
		return out
	end
	for _, id in typeIds do
		if not templateFor(folder, id, if shapeOf then shapeOf(id) else nil) then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

local function weld(part: BasePart, to: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function addEyes(enemy: any, visual: Visual)
	local part = enemy.part :: BasePart
	local size = enemy.radius * 2
	if size < 1.4 then
		return
	end
	local eye = math.clamp(size * 0.24, 0.35, 2.2)
	local front = enemy.radius * (if enemy.def.Shape == "Ball" then 0.78 else 0.98)
	local up = enemy.height * (if enemy.def.Shape == "Ball" then 0.12 else 0.18)
	for _, side in { -1, 1 } do
		local white = Instance.new("Part")
		white.Name = "Eye"
		white.Shape = Enum.PartType.Ball
		white.Size = Vector3.one * eye
		white.Color = Color3.new(1, 1, 1)
		white.Material = Enum.Material.SmoothPlastic
		white.CFrame = part.CFrame * CFrame.new(side * size * 0.2, up, -front)
		weld(white, part)
		white.Parent = part
		local pupil = Instance.new("Part")
		pupil.Name = "Pupil"
		pupil.Shape = Enum.PartType.Ball
		pupil.Size = Vector3.one * eye * 0.5
		pupil.Color = Color3.fromRGB(20, 16, 24)
		pupil.Material = Enum.Material.SmoothPlastic
		pupil.CFrame = white.CFrame * CFrame.new(0, 0, -eye * 0.32)
		weld(pupil, part)
		pupil.Parent = part
		table.insert(visual.parts, white)
		table.insert(visual.parts, pupil)
		visual.base[white] = 0
		visual.base[pupil] = 0
	end
end

local function playLoop(model: Model)
	local controller = model:FindFirstChildWhichIsA("AnimationController", true) or model:FindFirstChildWhichIsA("Humanoid", true)
	if not controller then
		return
	end
	local anim = model:FindFirstChild("Walk", true) or model:FindFirstChild("Idle", true)
	if not anim or not anim:IsA("Animation") then
		return
	end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = controller
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		track:Play()
	end
end

-- Los personajes de la Caja de herramientas guardan la animación de caminar dentro de su script
-- "Animate" (que se borra). Antes de borrarlo, se rescata esa Animation como "Walk".
local function rescueWalk(model: Model)
	local existing = model:FindFirstChild("Walk", true)
	if existing and existing:IsA("Animation") and not existing:FindFirstAncestorWhichIsA("LuaSourceContainer") then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Animation") then
			local name = string.lower(d.Name .. " " .. (if d.Parent then d.Parent.Name else ""))
			if string.find(name, "walk", 1, true) or string.find(name, "run", 1, true) then
				local copy = d:Clone()
				copy.Name = "Walk"
				copy.Parent = model
				return
			end
		end
	end
end

local function attachModel(enemy: any, template: Instance, visual: Visual): boolean
	if not template:IsA("Model") then
		return false
	end
	local part = enemy.part :: BasePart
	local model = template:Clone()
	rescueWalk(model)
	EnemyVisuals.sanitize(model)
	-- Escala: que mida la altura de la caja (Scale extra opcional con el atributo "Scale")
	local _, extents = model:GetBoundingBox()
	local extra = (template:GetAttribute("Scale") :: number?) or 1
	if extents.Y > 0.01 then
		local scale = math.max(enemy.height, EnemyCfg.ModelMinHeight or 0) / extents.Y * extra
		pcall(function()
			model:ScaleTo(model:GetScale() * scale)
		end)
	end
	-- Apoyado en el piso de la caja y mirando para el mismo lado (el frente del modelo es -Z;
	-- con el atributo "Yaw" en grados se corrige si el modelo mira para otro lado)
	local box, size = model:GetBoundingBox()
	local yaw = math.rad((template:GetAttribute("Yaw") :: number?) or 0)
	local pivotOffset = box:ToObjectSpace(model:GetPivot())
	local center = part.CFrame * CFrame.new(0, -enemy.height / 2 + size.Y / 2, 0) * CFrame.Angles(0, yaw, 0)
	model:PivotTo(center * pivotOffset)
	-- Personaje con articulaciones (R6/R15, zombies...): solo la raíz se suelda a la caja y el
	-- resto cuelga de sus articulaciones, así la animación mueve brazos y piernas.
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	local rigRoot = (model:FindFirstChild("HumanoidRootPart", true) or model.PrimaryPart) :: BasePart?
	local isRig = humanoid ~= nil and rigRoot ~= nil and model:FindFirstChildWhichIsA("Motor6D", true) ~= nil
	local tint = EnemyCfg.ModelTint or 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			visual.base[d] = d.Transparency
			table.insert(visual.parts, d)
			-- Color del enemigo: cada tipo se distingue aunque compartan modelo
			if tint > 0 and d.Transparency < 1 then
				d.Color = d.Color:Lerp(enemy.color, tint)
			end
			if isRig and d ~= rigRoot then
				d.Anchored = false
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
			else
				weld(d, part)
			end
		elseif d:IsA("Humanoid") then
			-- Solo para animar: sin nombre, sin barra, sin física propia
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			d.EvaluateStateMachine = false
		end
	end
	-- Barra de vida e indicador arriba del modelo (puede ser más alto que la caja)
	local top = -enemy.height / 2 + size.Y
	enemy.barGui.StudsOffset = Vector3.new(0, top + 1, 0)
	part:SetAttribute("VisualTop", top)
	model.Name = "Look"
	model.Parent = part
	visual.model = model
	visual.hitboxVisible = false
	part.Transparency = 1
	playLoop(model)
	return true
end

-- Se llama una vez al crear el enemigo.
function EnemyVisuals.attach(enemy: any)
	local visual: Visual = { model = nil, parts = {}, base = {}, hitboxVisible = true, highlight = nil, tinted = false, alpha = 0 }
	enemy.visual = visual
	local folder = if EnemyCfg.Models ~= false then modelsFolder() else nil
	local template = folder and templateFor(folder, enemy.typeId, enemy.def.Shape)
	local ok = false
	if template then
		local success, result = pcall(attachModel, enemy, template, visual)
		ok = success and result == true
		if not success then
			warn("[EnemyVisuals] No se pudo usar el modelo de " .. enemy.typeId .. ":", result)
		end
	end
	if not ok and EnemyCfg.Eyes then
		addEyes(enemy, visual)
	end
	if (enemy.golden or enemy.elite) and visual.model then
		local h = Instance.new("Highlight")
		h.FillColor = enemy.color
		h.OutlineColor = enemy.color
		h.FillTransparency = if enemy.elite then 0.75 else 0.6
		h.Parent = visual.model
	end
end

-- Transparencia del enemigo (0 visible, 1 enterrado). La usan Enemies.setHidden y la IA.
function EnemyVisuals.setTransparency(enemy: any, t: number)
	local visual: Visual? = enemy.visual
	if not visual then
		enemy.part.Transparency = t
		return
	end
	visual.alpha = t
	if visual.hitboxVisible then
		enemy.part.Transparency = t
	end
	for _, p in visual.parts do
		p.Transparency = if t >= 1 then 1 else math.max(visual.base[p] or 0, t)
	end
end

-- Cada frame: con modelo, refleja el color de la caja (parpadeo, quemadura) con un Highlight.
function EnemyVisuals.sync(enemy: any)
	local visual: Visual? = enemy.visual
	if not visual or not visual.model then
		return
	end
	local color = enemy.part.Color
	local tinted = color ~= enemy.color and visual.alpha < 1
	if tinted == visual.tinted and not tinted then
		return
	end
	visual.tinted = tinted
	if tinted then
		local h = visual.highlight
		if not h then
			local created = Instance.new("Highlight")
			created.OutlineTransparency = 1
			created.FillTransparency = 0.35
			created.DepthMode = Enum.HighlightDepthMode.Occluded
			created.Parent = visual.model
			visual.highlight = created
			h = created
		end
		(h :: Highlight).FillColor = color
	elseif visual.highlight then
		visual.highlight:Destroy()
		visual.highlight = nil
	end
end

return EnemyVisuals
