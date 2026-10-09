-- Perfil guardado (Profiles): carga, guardado, reintentos, bloqueo de sesión, versiones,
-- modo sin guardado, guardado automático y cierre del servidor. Usa el DataStore simulado
-- de mocks.luau (en memoria, con fallas a pedido).
local M = require("./mocks")
local Config = require("./Config")
local Profiles = require("./Profiles")

local Cfg = Config.Profiles
local DS = M.dataStore
local RunService = M.game:GetService("RunService")

local passed, failed = 0, 0
local function test(name, f)
	-- Cada prueba arranca con el DataStore sin fallas y un "servidor" nuevo
	DS.failNext = 0
	DS.accessDenied = false
	DS.onCall = nil
	Profiles._resetForTests()
	local ok, err = pcall(f)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FALLÓ " .. name .. "\n         " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end

local nextId = 100
local function newPlayer(userId)
	nextId += 1
	return M.addPlayer("P" .. (userId or nextId), userId or nextId)
end
local function record(p) return DS.data["Player_" .. p.UserId] end

print("Perfil guardado")
Profiles.init() -- guardado automático y BindToClose

test("jugador nuevo: perfil por defecto, listo y con el bloqueo de este servidor", function()
	local p = newPlayer()
	Profiles.load(p)
	eq(Profiles.status(p), "Ready", "estado")
	eq(p:GetAttribute("ProfileStatus"), "Ready", "atributo")
	eq(p:GetAttribute("Gold"), 0, "oro")
	local rec = record(p)
	assert(rec, "debería existir en el DataStore")
	eq(rec.Version, Profiles.SCHEMA_VERSION, "versión")
	eq(rec.Lock.JobId, M.game.JobId, "bloqueo")
end)

test("monedas: suma, resta, sin saldo negativo y validación", function()
	local p = newPlayer()
	Profiles.load(p)
	assert(Profiles.addCurrency(p, "Gold", 120), "sumar")
	eq(p:GetAttribute("Gold"), 120, "atributo publicado")
	assert(Profiles.addCurrency(p, "Gold", -20), "restar")
	eq(Profiles.get(p).Currencies.Gold, 100, "saldo")
	assert(not Profiles.addCurrency(p, "Gold", -101), "no deja saldo negativo")
	assert(not Profiles.addCurrency(p, "Robux", 5), "moneda inexistente")
	assert(not Profiles.addCurrency(p, "Gold", 1.5), "cantidad con decimales")
	assert(not Profiles.addCurrency(p, "Gold", 0 / 0), "NaN")
	assert(not Profiles.addCurrency(p, "Gold", "10" :: any), "texto")
	eq(Profiles.get(p).Currencies.Gold, 100, "nada cambió")
end)

test("al salir se guarda y se suelta; al volver está todo", function()
	local p = newPlayer()
	Profiles.load(p)
	Profiles.addCurrency(p, "Gems", 55)
	Profiles.chapter(p, "ruins").Unlocked = true
	Profiles.onPlayerRemoving(p)
	local rec = record(p)
	eq(rec.Data.Currencies.Gems, 55, "gemas guardadas")
	eq(rec.Lock, nil, "bloqueo soltado")
	-- Vuelve a entrar (otro objeto Player, mismo UserId)
	Profiles._resetForTests()
	local again = M.addPlayer("Otra vez", p.UserId)
	Profiles.load(again)
	eq(Profiles.get(again).Currencies.Gems, 55, "gemas")
	eq(Profiles.get(again).Chapters.ruins.Unlocked, true, "capítulo desbloqueado")
end)

test("reintentos: dos fallas seguidas y carga igual", function()
	local p = newPlayer()
	DS.failNext = 2
	Profiles.load(p)
	eq(Profiles.status(p), "Ready", "estado")
end)

test("DataStore caído: perfil temporal que nunca se escribe", function()
	local p = newPlayer()
	DS.failNext = 99
	Profiles.load(p)
	eq(Profiles.status(p), "Offline", "estado")
	eq(p:GetAttribute("ProfileStatus"), "Offline", "aviso al cliente")
	assert(Profiles.addCurrency(p, "Gold", 10), "se juega igual")
	DS.failNext = 0
	Profiles.onPlayerRemoving(p)
	eq(record(p), nil, "no se escribió nada")
end)

test("Studio sin acceso a las APIs: no reintenta y juega sin guardar", function()
	local p = newPlayer()
	DS.accessDenied = true
	local before = DS.calls
	Profiles.load(p)
	eq(Profiles.status(p), "Offline", "estado")
	eq(DS.calls - before, 1, "un solo intento")
	-- Los siguientes jugadores ni lo intentan
	local q = newPlayer()
	Profiles.load(q)
	eq(DS.calls - before, 1, "sin más pedidos")
	eq(Profiles.status(q), "Offline", "estado del segundo")
end)

test("perfil abierto en otro servidor: espera, y si no lo suelta lo toma", function()
	local p = newPlayer()
	DS.data["Player_" .. p.UserId] = {
		Version = 1,
		Data = { Currencies = { Gold = 77 } },
		Lock = { JobId = "otro-servidor", Time = M.os.time() },
	}
	local t0 = M.now
	Profiles.load(p)
	eq(Profiles.status(p), "Ready", "estado")
	eq(Profiles.get(p).Currencies.Gold, 77, "conserva los datos")
	eq(record(p).Lock.JobId, M.game.JobId, "ahora es nuestro")
	assert(M.now - t0 >= Cfg.LockRetryDelay * (Cfg.LockRetries - 1), "debería haber esperado")
end)

test("el otro servidor lo suelta mientras esperamos: se carga sin robarlo", function()
	local p = newPlayer()
	local key = "Player_" .. p.UserId
	DS.data[key] = { Version = 1, Data = {}, Lock = { JobId = "otro-servidor", Time = M.os.time() } }
	local calls = 0
	DS.onCall = function()
		calls += 1
		if calls == 2 then
			DS.data[key].Lock = nil -- el otro guardó y soltó
		end
	end
	Profiles.load(p)
	eq(Profiles.status(p), "Ready", "estado")
	eq(calls, 2, "cargó en el segundo intento")
end)

test("bloqueo abandonado (servidor caído): se toma enseguida", function()
	local p = newPlayer()
	DS.data["Player_" .. p.UserId] = {
		Version = 1,
		Data = {},
		Lock = { JobId = "servidor-caido", Time = M.os.time() - Cfg.LockExpire - 10 },
	}
	local t0 = M.now
	Profiles.load(p)
	eq(Profiles.status(p), "Ready", "estado")
	eq(M.now, t0, "sin esperas")
end)

test("si otro servidor toma el perfil, este deja de guardar y saca al jugador", function()
	local p = newPlayer()
	Profiles.load(p)
	Profiles.addCurrency(p, "Gold", 500)
	local rec = record(p)
	rec.Lock = { JobId = "otro-servidor", Time = M.os.time() }
	rec.Data.Currencies.Gold = 3
	Profiles.saveSoon(p)
	eq(record(p).Data.Currencies.Gold, 3, "no pisó los datos del otro")
	assert(rawget(p, "_raw").kicked, "debería sacar al jugador")
	Profiles.onPlayerRemoving(p)
	eq(record(p).Data.Currencies.Gold, 3, "tampoco al salir")
end)

test("si otro servidor lo tomó y ya lo soltó (sin Lock), este tampoco lo pisa", function()
	local p = newPlayer()
	Profiles.load(p)
	local rec = record(p)
	rec.Lock = nil
	rec.Data.Currencies.Gold = 9
	Profiles.addCurrency(p, "Gold", 100)
	Profiles.saveSoon(p)
	eq(record(p).Data.Currencies.Gold, 9, "intacto")
end)

test("vuelve a entrar al MISMO servidor antes de que termine de guardar: espera esa sesión", function()
	local p = newPlayer()
	-- Bloqueo de la sesión anterior en este mismo servidor (mismo JobId, otra sesión)
	DS.data["Player_" .. p.UserId] = {
		Version = 1,
		Data = { Currencies = { Gold = 5 } },
		Lock = { JobId = M.game.JobId, Session = "sesion-anterior", Time = M.os.time() },
	}
	local key = "Player_" .. p.UserId
	local calls = 0
	DS.onCall = function()
		calls += 1
		if calls == 2 then
			-- la sesión anterior termina de guardar y suelta
			DS.data[key] = { Version = 1, Data = { Currencies = { Gold = 50 } } }
		end
	end
	Profiles.load(p)
	eq(calls, 2, "esperó")
	eq(Profiles.get(p).Currencies.Gold, 50, "lee lo último que guardó la sesión anterior")
end)

test("después de soltar el perfil, un guardado tardío no lo vuelve a bloquear", function()
	local p = newPlayer()
	Profiles.load(p)
	Profiles.onPlayerRemoving(p)
	eq(record(p).Lock, nil, "soltado")
	Profiles.saveSoon(p) -- ya no hay sesión: no hace nada
	eq(record(p).Lock, nil, "sigue suelto")
end)

test("en un servidor real, un error 403 se reintenta y no apaga el guardado", function()
	M.isStudio = false
	local p = newPlayer()
	DS.onCall = function()
		DS.onCall = nil
		error("403: Forbidden (simulado)")
	end
	Profiles.load(p)
	M.isStudio = true
	eq(Profiles.status(p), "Ready", "cargó en el reintento")
end)

test("cierre del servidor con una carga a medio terminar: el perfil queda suelto", function()
	local p = newPlayer()
	DS.onCall = function()
		DS.onCall = nil
		M.closeServer() -- el servidor cierra mientras carga
	end
	Profiles.load(p)
	eq(record(p).Lock, nil, "soltado")
	eq(Profiles.get(p), nil, "sin sesión")
end)

test("perfil sin versión (formato viejo): se migra y se completa", function()
	local p = newPlayer()
	DS.data["Player_" .. p.UserId] = { Data = { Currencies = { Gold = 50 } } }
	Profiles.load(p)
	local data = Profiles.get(p)
	eq(data.Currencies.Gold, 50, "oro")
	eq(data.Currencies.Gems, 0, "gemas agregadas")
	eq(data.Stats.Runs, 0, "estadísticas agregadas")
	eq(record(p).Version, Profiles.SCHEMA_VERSION, "guardado con la versión actual")
end)

test("datos rotos se descartan sin romper el perfil", function()
	local p = newPlayer()
	DS.data["Player_" .. p.UserId] = {
		Version = 1,
		Data = {
			Currencies = { Gold = -5, Gems = "mucho", Stones = 3.7 },
			Chapters = { forest = "sí", ruins = { Unlocked = true, Clears = -1 } },
			Stats = "nada",
		},
	}
	Profiles.load(p)
	local data = Profiles.get(p)
	eq(data.Currencies.Gold, 0, "oro negativo")
	eq(data.Currencies.Gems, 0, "gemas texto")
	eq(data.Currencies.Stones, 3, "decimales")
	eq(data.Chapters.forest, nil, "capítulo roto")
	eq(data.Chapters.ruins.Unlocked, true, "capítulo bueno")
	eq(data.Chapters.ruins.Clears, 0, "victorias negativas")
	eq(data.Stats.Kills, 0, "estadísticas")
end)

test("migraciones: se aplican en orden al subir de versión", function()
	local p = newPlayer()
	DS.data["Player_" .. p.UserId] = { Version = 1, Data = { Currencies = { Gold = 10 } } }
	-- Versión 2 de ejemplo: duplica el oro (solo para la prueba)
	Profiles.SCHEMA_VERSION = 2
	Profiles.Migrations[1] = function(data)
		data.Currencies.Gold *= 2
		return data
	end
	local ok, err = pcall(Profiles.load, p)
	Profiles.SCHEMA_VERSION = 1
	Profiles.Migrations[1] = nil
	assert(ok, err)
	eq(Profiles.get(p).Currencies.Gold, 20, "migrado")
	eq(record(p).Version, 2, "guardado como versión 2")
end)

test("perfil de una versión más nueva: se usa pero no se toca", function()
	local p = newPlayer()
	DS.data["Player_" .. p.UserId] = { Version = 99, Data = { Currencies = { Gold = 40 } } }
	Profiles.load(p)
	eq(Profiles.status(p), "Offline", "estado")
	eq(Profiles.get(p).Currencies.Gold, 40, "datos")
	Profiles.addCurrency(p, "Gold", 1000)
	Profiles.onPlayerRemoving(p)
	eq(record(p).Version, 99, "intacto")
	eq(record(p).Data.Currencies.Gold, 40, "sin cambios")
end)

test("se va mientras carga: el perfil se suelta enseguida", function()
	local p = newPlayer()
	DS.onCall = function()
		DS.onCall = nil
		Profiles.onPlayerRemoving(p) -- se fue durante el pedido
	end
	Profiles.load(p)
	eq(Profiles.get(p), nil, "sin sesión")
	local rec = record(p)
	assert(rec, "existe")
	eq(rec.Lock, nil, "soltado")
end)

test("guardado automático cada AutoSaveInterval", function()
	local p = newPlayer()
	Profiles.load(p)
	Profiles.addCurrency(p, "Stones", 4)
	M.advance(Cfg.AutoSaveInterval - 1)
	RunService.Heartbeat:Fire(1)
	eq(record(p).Data.Currencies.Stones, 0, "todavía no")
	M.advance(2)
	RunService.Heartbeat:Fire(1)
	eq(record(p).Data.Currencies.Stones, 4, "guardado")
	eq(record(p).Lock.JobId, M.game.JobId, "sigue bloqueado")
end)

test("cierre del servidor: guarda y suelta a todos", function()
	local a, b = newPlayer(), newPlayer()
	Profiles.load(a)
	Profiles.load(b)
	Profiles.addCurrency(a, "Gold", 1)
	Profiles.addCurrency(b, "Gold", 2)
	M.closeServer()
	eq(record(a).Data.Currencies.Gold, 1, "a")
	eq(record(b).Data.Currencies.Gold, 2, "b")
	eq(record(a).Lock, nil, "a soltado")
	eq(record(b).Lock, nil, "b soltado")
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then
	error("hay pruebas que fallaron")
end
