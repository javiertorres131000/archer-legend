import sys, os
root = sys.argv[1]
def ed(p, pairs):
    p = os.path.join(root, p)
    b = open(p, 'rb').read().decode('utf-8')
    N = '\r\n' if '\r\n' in b else '\n'
    for o, n in pairs:
        o = o.replace('\n', N); n = n.replace('\n', N)
        if n in b and o not in b:
            continue  # ya aplicado
        assert b.count(o) == 1, (p, o[:80])
        b = b.replace(o, n)
    open(p, 'wb').write(b.encode('utf-8'))
ed('src/server/Remotes.lua', [
('	SkillFx = event("SkillFx"),\n', '''	SkillFx = event("SkillFx"),
	-- jugador -> servidor: lanzar la definitiva del arma (UltimateService valida la carga)
	UltimateRequest = event("UltimateRequest"),
	-- servidor -> todos: (userId, Id del arma, origen, dirección, hora del servidor) definitiva
	-- lanzada; la dibuja Client/UltimateFx
	UltimateFx = event("UltimateFx"),
'''),
])
ed('src/server/Run.lua', [
('local Dash = require(script.Parent.Dash)\n', 'local Dash = require(script.Parent.Dash)\nlocal UltimateService = require(script.Parent.UltimateService)\n'),
('	Dash.init(Remotes)\n', '	Dash.init(Remotes)\n	UltimateService.init(Remotes, Enemies) -- definitivas de las armas especiales\n'),
('	table.clear(bossesKilled)\n', '	table.clear(bossesKilled)\n	UltimateService.reset() -- partida nueva: definitivas sin carga\n'),
])
ed('src/server/SkillEffects.lua', [
('local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Weapons"))\n',
 'local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Weapons"))\nlocal UltimateService = require(script.Parent.UltimateService)\n'),
('	-- Poder del arma especial (fuego, sangrado, rayos, grietas...)\n	weaponOnHit(owner, e, dealt, source)\n',
 '	-- Poder del arma especial (fuego, sangrado, rayos, grietas...)\n	weaponOnHit(owner, e, dealt, source)\n	-- Cada golpe carga la definitiva del arma\n	if source == "melee" or source == "arrow" then\n		UltimateService.addCharge(owner)\n	end\n'),
])
ed('src/shared/Weapons.lua', [
('''		Power = { Color = Color3.fromRGB(230, 20, 45), Bleed = 0.25, Finisher = { Kind = "Blast", Radius = 13, Ahead = 5, Mult = 2.2 } },
''', '''		Power = { Color = Color3.fromRGB(230, 20, 45), Bleed = 0.25, Finisher = { Kind = "Blast", Radius = 13, Ahead = 5, Mult = 2.2 } },
		-- Definitiva (Server/UltimateService + Client/UltimateFx): se carga con 45 golpes, tecla Q
		Ultimate = {
			Name = "Luna Sangrienta",
			Color = Color3.fromRGB(235, 25, 50),
			ChargeHits = 45,
			Duration = 3.2,
			FirstAt = 0.5, -- tajos iniciales
			FirstFrac = 0.12,
			PullAt = 1.2, -- atrae a los enemigos
			Pull = 10,
			FinalAt = 2.6, -- golpe final
			Radius = 24,
			Mult = 14, -- × tu daño × el DamageMult del arma
			BossMult = 0.5,
			Bleed = 0.3,
		},
'''),
('--   Tint (opcional):', '--   Ultimate (opcional): habilidad definitiva con cinemática (ver Server/UltimateService).\n--   Tint (opcional):'),
])
ed('src/shared/Config.lua', [
('-- Ventajas de pelear cuerpo a cuerpo', '''-- Definitivas de las armas especiales (Shared/Weapons › Ultimate). Texturas de los efectos
-- (assets/vfx/ultimate): subirlas y pegar los IDs; vacías = respaldo de Roblox.
Config.Ultimate = {
	Textures = {
		Tajo = "",
		Anillo = "",
		Espiral = "",
		Grietas = "",
		Destello = "",
		Energia = "",
	},
}

-- Ventajas de pelear cuerpo a cuerpo'''),
])
print('patched', root)
