--!strict
-- CrateLooks (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > CrateLooks
-- Trajes detallados de los premios de personaje: piezas (armadura, cuernos, alas, ojos...)
-- pegadas al cuerpo, color y material de la piel y partículas. Un premio con traje acá se ve así:
--   · en tu avatar al equiparlo (CrateEquip, avatar R15: las piezas se sueldan a cada segmento)
--   · en el Index y en la animación de apertura (CrateModels, sobre el modelo de bloques)
-- Los premios sin traje usan el aspecto simple de CrateItems (Look).
--
-- CÓMO AGREGAR UN TRAJE: una entrada con el Id del premio. Cada pieza:
--   { Seg = "Torso" | "Head" | "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg",
--     Name, Size, Color, Material, CF = posición respecto del centro de ese segmento,
--     Transparency?, Light? = { Color, Range, Brightness }, Face? = true }
-- Las medidas son las de un cuerpo de bloques clásico (R6): torso 2x2x1, brazos y piernas
-- 1x2x1 (CF relativo al centro del miembro entero) y cabeza ~1.2. Face = true: la pieza va
-- pegada al frente de la cara (su Z se calcula sola según la cabeza).

local CrateLooks = {}

export type LookPart = {
	Seg: string,
	Name: string,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	CF: CFrame,
	Transparency: number?,
	Light: { Color: Color3, Range: number, Brightness: number }?,
	Face: boolean?,
	Shape: (Enum.PartType | "Wedge")?,
}
export type Look = {
	Skin: Color3, -- color de todo el cuerpo
	SkinMaterial: Enum.Material,
	Parts: { LookPart },
	Embers: { Colors: { Color3 }, Rate: number }?, -- brasas que salen del pecho
}

local C = Color3.fromRGB

---------------------------------------------------------------------
-- Demonio Ígneo V3: máscara reforzada, alas demoníacas y magma
---------------------------------------------------------------------
do
    local lava = C(255, 91, 13)
    local gold = C(255, 119, 22)
    local obsidian = C(23, 17, 24)
    local iron = C(51, 25, 32)
    local crimson = C(111, 20, 30)
    local metal, neon = Enum.Material.Metal, Enum.Material.Neon
    local parts: { LookPart } = {}

    local function add(seg: string, name: string, size: Vector3, color: Color3, material: Enum.Material, cf: CFrame, shape: (Enum.PartType | "Wedge")?, alpha: number?)
        table.insert(parts, { Seg=seg, Name=name, Size=size, Color=color, Material=material, CF=cf, Shape=shape, Transparency=alpha })
    end
    local function plate(seg: string, name: string, size: Vector3, pos: Vector3, color: Color3, rot: CFrame?)
        add(seg,name,size,color,metal,CFrame.new(pos)*(rot or CFrame.new()))
    end

    -- Casco integral: cubre por completo el rostro R15 (frente = -Z).
    add('Head','CascoObsidiana',Vector3.new(1.37,1.37,1.36),obsidian,metal,CFrame.new(0,0,0),Enum.PartType.Block)
    plate('Head','ViseraBlindada',Vector3.new(1.27,.52,.12),Vector3.new(0,.16,-.73),iron)
    plate('Head','Barbilla',Vector3.new(1.12,.32,.15),Vector3.new(0,-.43,-.72),iron)
    plate('Head','NarizMascara',Vector3.new(.18,.56,.19),Vector3.new(0,-.07,-.81),obsidian)
    for _,side in {-1,1} do
        plate('Head','OjoInfernal',Vector3.new(.34,.13,.05),Vector3.new(side*.31,.13,-.81),lava,CFrame.Angles(0,0,side*.22))
        plate('Head','Cejas',Vector3.new(.47,.11,.17),Vector3.new(side*.3,.33,-.81),obsidian,CFrame.Angles(0,0,side*.28))
        plate('Head','CuernoBase',Vector3.new(.34,.51,.34),Vector3.new(side*.43,.78,.03),obsidian,CFrame.Angles(0,0,-side*.28))
        plate('Head','CuernoMedio',Vector3.new(.24,.48,.24),Vector3.new(side*.57,1.13,.01),iron,CFrame.Angles(0,0,-side*.42))
        add('Head','CuernoPunta',Vector3.new(.16,.36,.16),lava,neon,CFrame.new(side*.74,1.47,.01)*CFrame.Angles(0,0,-side*.5),"Wedge")
        plate('Head','Mejilla',Vector3.new(.15,.5,.16),Vector3.new(side*.62,-.14,-.64),crimson,CFrame.Angles(0,0,side*.25))
    end

    -- Mandíbula y ranuras de respiración de la máscara.
    plate('Head','MandibulaCentral',Vector3.new(.58,.18,.18),Vector3.new(0,-.48,-.83),obsidian)
    for _,side in {-1,1} do
        plate('Head','ColmilloMascara',Vector3.new(.12,.27,.14),Vector3.new(side*.36,-.40,-.84),iron,CFrame.Angles(0,0,side*.25))
        plate('Head','Respiradero',Vector3.new(.08,.19,.04),Vector3.new(side*.17,-.36,-.93),lava)
    end

    -- Coraza de varias capas y centro brillante.
    plate('Torso','PetoObsidiana',Vector3.new(2.18,1.66,.3),Vector3.new(0,.17,-.63),obsidian)
    plate('Torso','PlacaPecho',Vector3.new(1.35,1.2,.15),Vector3.new(0,.14,-.84),iron)
    plate('Torso','Cinturon',Vector3.new(2.12,.24,1.14),Vector3.new(0,-.78,0),obsidian)
    plate('Torso','Hebilla',Vector3.new(.4,.32,.12),Vector3.new(0,-.75,-.68),lava)
    add('Torso','CorazonDeLava',Vector3.new(.45,.45,.17),lava,neon,CFrame.new(0,.29,-.96)*CFrame.Angles(0,0,math.rad(45)))
    table.insert(parts, {Seg='Torso',Name='LuzNucleo',Size=Vector3.new(.15,.15,.12),Color=lava,Material=neon,CF=CFrame.new(0,.29,-1.07),Light={Color=lava,Range=7,Brightness=1.1}})
    for _,side in {-1,1} do
        plate('Torso','CostillaDeMagma',Vector3.new(.1,.95,.09),Vector3.new(side*.78,.12,-.85),lava,CFrame.Angles(0,0,side*.18))
        plate('Torso','PlacaCostado',Vector3.new(.42,1.25,.25),Vector3.new(side*1.04,.05,-.51),crimson,CFrame.Angles(0,0,side*.12))
        plate('Torso','EspinaHombro',Vector3.new(.28,.56,.3),Vector3.new(side*.96,1.05,-.05),obsidian,CFrame.Angles(0,0,-side*.38))
        local arm=if side == -1 then 'LeftArm' else 'RightArm'
        local leg=if side == -1 then 'LeftLeg' else 'RightLeg'
        plate(arm,'HombreraPesada',Vector3.new(1.35,.47,1.35),Vector3.new(0,.72,0),obsidian)
        plate(arm,'PlacaHombrera',Vector3.new(1.13,.22,1.4),Vector3.new(0,.89,-.02),crimson)
        plate(arm,'BrazalBlindado',Vector3.new(1.14,.65,1.13),Vector3.new(0,-.36,0),iron)
        plate(arm,'BrazalLava',Vector3.new(1.17,.12,1.16),Vector3.new(0,-.65,0),lava)
        plate(arm,'GuanteInfernal',Vector3.new(1.1,.32,1.12),Vector3.new(0,-.9,0),obsidian)
        plate(leg,'Muslera',Vector3.new(1.16,.59,1.15),Vector3.new(0,.57,0),crimson)
        plate(leg,'Rodillera',Vector3.new(1.19,.26,1.18),Vector3.new(0,-.03,0),obsidian)
        plate(leg,'GrebaObsidiana',Vector3.new(1.14,.66,1.13),Vector3.new(0,-.46,0),iron)
        plate(leg,'GrebaMagma',Vector3.new(.12,.55,.09),Vector3.new(0,-.43,-.62),lava)
        plate(leg,'Bota',Vector3.new(1.15,.27,1.34),Vector3.new(0,-.9,-.09),obsidian)

        -- V3: alas demoníacas compactas (no tapan toda la pantalla).
        -- Abiertas en X y ligeramente hacia atrás (+Z), con membranas segmentadas.
        -- Los paneles se solapan para parecer un ala continua, no cuchillas sueltas.
        local ribs = {
            {x=.68, y=.63, a=-.36, len=1.45},
            {x=1.20, y=.96, a=-.72, len=1.65},
            {x=1.77, y=.86, a=-1.02, len=1.58},
            {x=2.21, y=.37, a=-1.34, len=1.36},
        }
        for i, rib in ipairs(ribs) do
            local x = side * rib.x
            local ang = side * rib.a
            local root = CFrame.new(x, rib.y, .93) * CFrame.Angles(0, side*.16, ang)
            plate('Torso','AlaHueso_'..i,Vector3.new(.15,rib.len,.18),Vector3.new(x,rib.y,.93),obsidian,CFrame.Angles(0,side*.16,ang))
            -- Borde luminoso del hueso
            add('Torso','AlaVena_'..i,Vector3.new(.055,rib.len*.74,.06),lava,neon,root*CFrame.new(0,-.10,-.115),nil,.08)
            if i < #ribs then
                local nextRib=ribs[i+1]
                local midX=side*((rib.x+nextRib.x)*.5)
                local midY=(rib.y+nextRib.y)*.5-.43
                local angle=side*((rib.a+nextRib.a)*.5)
                -- Paneles triangulares inclinados, de aspecto membranoso
                add('Torso','MembranaAla_'..i,Vector3.new(.88,1.36,.095),crimson,Enum.Material.Glass,
                    CFrame.new(midX,midY,1.02)*CFrame.Angles(0,side*.13,angle),"Wedge",.13)
                add('Torso','MembranaBrasa_'..i,Vector3.new(.49,.98,.055),lava,neon,
                    CFrame.new(midX+side*.08,midY-.12,1.09)*CFrame.Angles(0,side*.13,angle),"Wedge",.65)
            end
            add('Torso','PuntaAla_'..i,Vector3.new(.22,.36,.22),obsidian,metal,
                root*CFrame.new(0,rib.len*.49,0),"Wedge")
        end
        -- Espinas sobre la espalda, sin invadir la cara del personaje.
        for i=1,3 do
            add('Torso','EspinaDorsal_'..i,Vector3.new(.19,.32,.21),obsidian,metal,
                CFrame.new(side*.30, .75-(i-1)*.40, .72)*CFrame.Angles(math.rad(22),0,side*.20),"Wedge")
        end
    end
    CrateLooks.FireDemon = {
        Skin=obsidian, SkinMaterial=Enum.Material.Slate,
        Parts=parts, Embers={ Colors={lava,gold}, Rate=6 },
    } :: Look
end

---------------------------------------------------------------------
-- Armar un traje sobre un cuerpo
---------------------------------------------------------------------

-- Dónde está cada segmento "clásico" en este cuerpo: devuelve (pieza a la que se pega,
-- CFrame del centro del segmento como si fuera de bloques clásico).
type Resolver = (seg: string, offsetY: number) -> (BasePart?, CFrame?)

local function find(model: Instance, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

-- Avatar R15: el miembro clásico de 2 studs se reparte en 3 piezas (de arriba abajo). Cada pieza
-- del traje se suelda a la que le toca por altura, así acompaña la animación.
local function r15(character: Model): Resolver
	return function(seg: string, offsetY: number): (BasePart?, CFrame?)
		if seg == "Head" then
			local head = find(character, "Head")
			return head, if head then head.CFrame else nil
		elseif seg == "Torso" then
			local upper = find(character, "UpperTorso")
			if not upper then
				return nil, nil
			end
			return upper, upper.CFrame * CFrame.new(0, upper.Size.Y / 2 - 1, 0)
		end
		local side = if string.sub(seg, 1, 4) == "Left" then "Left" else "Right"
		local limb = if string.find(seg, "Arm") then "Arm" else "Leg"
		local upper = find(character, side .. "Upper" .. limb)
		if not upper then
			return nil, nil
		end
		local center = upper.CFrame * CFrame.new(0, upper.Size.Y / 2 - 1, 0)
		local partName = if offsetY >= 0.2 then side .. "Upper" .. limb
			elseif offsetY > -0.75 then side .. "Lower" .. limb
			else side .. (if limb == "Arm" then "Hand" else "Foot")
		return find(character, partName) or upper, center
	end
end

-- Modelo de bloques de CrateModels (Torso, Head, Arm, Leg; izquierda = X negativa)
local function blocky(model: Model): Resolver
	local root = model.PrimaryPart
	local origin = if root then root.CFrame else model:GetPivot()
	return function(seg: string, _offsetY: number): (BasePart?, CFrame?)
		if seg == "Head" or seg == "Torso" then
			local p = find(model, seg)
			return p, if p then p.CFrame else nil
		end
		local wantLeft = string.sub(seg, 1, 4) == "Left"
		local name = if string.find(seg, "Arm") then "Arm" else "Leg"
		for _, c in model:GetChildren() do
			if c:IsA("BasePart") and c.Name == name then
				local x = origin:PointToObjectSpace(c.Position).X
				if (x < 0) == wantLeft then
					return c, c.CFrame
				end
			end
		end
		return nil, nil
	end
end

local function build(look: Look, folder: Instance, resolve: Resolver, weld: boolean)
	for _, def in look.Parts do
		local base, center = resolve(def.Seg, def.CF.Position.Y)
		if not base or not center then
			continue
		end
		local cf = def.CF
		if def.Face then
			-- Pegada al frente de la cabeza, apenas afuera
			cf = CFrame.new(cf.Position.X, cf.Position.Y, -base.Size.Z / 2 - def.Size.Z / 2 + 0.02) * cf.Rotation
		end
		local p: BasePart
		if def.Shape == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = def.Shape or Enum.PartType.Block
			p = part
		end
		p.Name = def.Name
		p.Size = def.Size
		p.Color = def.Color
		p.Material = def.Material
		p.Transparency = def.Transparency or 0
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = def.Material ~= Enum.Material.Neon
		p.CFrame = center * cf
		p.Anchored = not weld
		if weld then
			local w = Instance.new("WeldConstraint")
			w.Part0 = base
			w.Part1 = p
			w.Parent = p
		end
		if def.Light then
			local light = Instance.new("PointLight")
			light.Color = def.Light.Color
			light.Range = def.Light.Range
			light.Brightness = def.Light.Brightness
			light.Parent = p
		end
		p.Parent = folder
	end
	if look.Embers then
		local torso, center = resolve("Torso", 0)
		if torso and center then
			local emitterPart = Instance.new("Part")
			emitterPart.Name = "Brasas"
			emitterPart.Size = Vector3.new(0.2, 0.2, 0.2)
			emitterPart.Transparency = 1
			emitterPart.CanCollide = false
			emitterPart.CanTouch = false
			emitterPart.CanQuery = false
			emitterPart.Massless = true
			emitterPart.CFrame = center * CFrame.new(0, 0, 0.6)
			emitterPart.Anchored = not weld
			if weld then
				local w = Instance.new("WeldConstraint")
				w.Part0 = torso
				w.Part1 = emitterPart
				w.Parent = emitterPart
			end
			local colors = look.Embers.Colors
			local e = Instance.new("ParticleEmitter")
			e.Name = "Brasas"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = look.Embers.Rate
			e.Lifetime = NumberRange.new(0.4, 1)
			e.Speed = NumberRange.new(0.5, 2)
			e.SpreadAngle = Vector2.new(45, 45)
			e.Color = ColorSequence.new(colors[1], colors[#colors])
			e.Size = NumberSequence.new(0.14, 0)
			e.LightEmission = 0.8
			e.Parent = emitterPart
			emitterPart.Parent = folder
		end
	end
end

-- Pone el traje en un avatar R15 (soldado, sigue las animaciones). Devuelve la carpeta creada.
function CrateLooks.applyToCharacter(prizeId: string, character: Model): Folder?
	local look = (CrateLooks :: any)[prizeId] :: Look?
	if type(look) ~= "table" then
		return nil
	end
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = look.Skin
			d.Material = look.SkinMaterial
		end
	end
	local existing = character:FindFirstChild("CrateLook")
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "CrateLook"
	build(look, folder, r15(character), true)
	folder.Parent = character
	return folder
end

-- Pone el traje en un modelo de bloques de CrateModels (piezas ancladas, para vistas previas)
function CrateLooks.applyToBlocky(prizeId: string, model: Model)
	local look = (CrateLooks :: any)[prizeId] :: Look?
	if type(look) ~= "table" then
		return
	end
	for _, name in { "Torso", "Head", "Arm", "Leg", "Hand" } do
		for _, c in model:GetChildren() do
			if c:IsA("BasePart") and c.Name == name then
				c.Color = look.Skin
				c.Material = look.SkinMaterial
			end
		end
	end
	build(look, model, blocky(model), false)
end

function CrateLooks.has(prizeId: string): boolean
	return type((CrateLooks :: any)[prizeId]) == "table"
end

return CrateLooks
