-- Efectos de las skins (Shared/SkinFx) y flechas con skin (Client/SkinArrowFx).
-- Revisa los datos y que las flechas del pool queden limpias; cómo se ven solo se ve en Studio.
local M = require("./mocks")
local SkinFx = require("./SkinFx")
local CrateItems = require("./CrateItems")
local FxStyles = require("./FxStyles")
local SkinArrowFx = require("./SkinArrowFx")

local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end

print("Efectos de skins")

test("cada skin con efectos es un personaje de las cajas y tiene sus datos completos", function()
	local n = 0
	for id, skin in SkinFx.Skins do
		n += 1
		local prize = CrateItems.ById[id]
		assert(prize, id .. ": no está en CrateItems")
		eq(CrateItems.slotOf(prize), "Character", id .. ": tiene que ser un personaje")
		for _, k in { "hot", "mid", "dark" } do
			assert(type(skin.Colors[k]) == "table", id .. ": falta el color " .. k)
		end
		local a = skin.Arrow
		if a then
			assert(FxStyles.get(a.Style), id .. ": el estilo " .. tostring(a.Style) .. " no existe en FxStyles")
			assert(a.Flames >= 0 and a.Embers >= 0 and a.Light >= 0, id .. ": valores negativos")
			assert(a.TrailLife > 0 and a.TrailWidth > 0 and a.ImpactSize > 0, id .. ": estela o impacto en cero")
		end
	end
	assert(n >= 1, "no hay skins")
	assert(SkinFx.Skins.FireDemon and SkinFx.Skins.FireDemon.Arrow, "el Demonio Ígneo tiene flechas propias")
end)

test("la skin sale del atributo CrateLook del personaje", function()
	local char = M.Instance.new("Model")
	eq(SkinFx.forCharacter(char), nil, "sin skin")
	char:SetAttribute("CrateLook", "Knight") -- premio sin efectos
	eq(SkinFx.forCharacter(char), nil, "skin sin efectos")
	char:SetAttribute("CrateLook", "FireDemon")
	local id, skin = SkinFx.forCharacter(char)
	eq(id, "FireDemon", "id")
	eq(skin, SkinFx.Skins.FireDemon, "datos")
	eq(SkinFx.forCharacter(nil), nil, "sin personaje")
	eq(SkinFx.get(123), nil, "id inválido")
end)

test("las flechas usan la skin del que dispara (no las enemigas ni las de otros)", function()
	local demon = M.addPlayer("Demonio")
	local other = M.addPlayer("Comun")
	demon:LoadCharacter()
	other:LoadCharacter()
	demon.Character:SetAttribute("CrateLook", "FireDemon")
	eq(SkinArrowFx.forOwner(demon.UserId), SkinFx.Skins.FireDemon, "flecha del demonio")
	eq(SkinArrowFx.forOwner(other.UserId), nil, "flecha común")
	eq(SkinArrowFx.forOwner(0), nil, "proyectil enemigo")
	eq(SkinArrowFx.forOwner(99999), nil, "jugador que ya no está")
	demon.Character:SetAttribute("CrateLook", nil) -- se la sacó
	eq(SkinArrowFx.forOwner(demon.UserId), nil, "sin la skin puesta")
end)

local function arrow()
	local part = M.Instance.new("Part")
	part.Size = M.Vector3.new(0.1, 0.1, 2.2)
	part.Material = M.Enum.Material.Wood
	local head = M.Instance.new("Part")
	head.Name = "Head"
	-- (en la imitación IsA compara la clase exacta; en Roblox un Part también es BasePart)
	rawget(head, "_raw").IsA = function(_, cls) return cls == "Part" or cls == "BasePart" end
	head.Parent = part
	return part, head
end

test("vestir y limpiar una flecha del pool", function()
	local skin = SkinFx.Skins.FireDemon
	local part, head = arrow()
	SkinArrowFx.decorate(part, skin, false)
	eq(part.Material, skin.Arrow.ShaftMaterial, "vara")
	eq(part.Color, skin.Arrow.Shaft, "color de la vara")
	eq(tostring(head.Material), tostring(M.Enum.Material.Neon), "punta que brilla")
	local fx = part:FindFirstChild("SkinFx")
	assert(fx, "adjunto con efectos")
	assert(fx:FindFirstChild("Llamas") and fx:FindFirstChild("Brasas"), "llamas y brasas")
	assert(fx:FindFirstChildOfClass("PointLight"), "luz")
	SkinArrowFx.decorate(part, skin, false) -- reusar no duplica
	local count = 0
	for _, c in part:GetChildren() do
		if c.Name == "SkinFx" then count += 1 end
	end
	eq(count, 1, "un solo adjunto")
	SkinArrowFx.clear(part)
	eq(part:FindFirstChild("SkinFx"), nil, "limpia")
	SkinArrowFx.clear(part) -- limpiar dos veces no rompe
end)

test("calidad baja: solo colores, sin partículas ni luz", function()
	local part = arrow()
	SkinArrowFx.decorate(part, SkinFx.Skins.FireDemon, true)
	eq(part.Material, SkinFx.Skins.FireDemon.Arrow.ShaftMaterial, "vara")
	eq(part:FindFirstChild("SkinFx"), nil, "sin efectos")
end)

test("las luces de las flechas tienen tope y se liberan", function()
	local parts = {}
	local withLight = 0
	for i = 1, 12 do
		local part = arrow()
		SkinArrowFx.decorate(part, SkinFx.Skins.FireDemon, false)
		if part.SkinFx:FindFirstChildOfClass("PointLight") then withLight += 1 end
		table.insert(parts, part)
	end
	assert(withLight <= 6, "como mucho 6 luces, hay " .. withLight)
	assert(withLight >= 1, "alguna luz")
	for _, part in parts do SkinArrowFx.clear(part) end
	local again = arrow()
	SkinArrowFx.decorate(again, SkinFx.Skins.FireDemon, false)
	assert(again.SkinFx:FindFirstChildOfClass("PointLight"), "al liberar, vuelve a haber luz")
	SkinArrowFx.clear(again)
end)

print(string.format("%d pruebas, 0 fallas", passed))
