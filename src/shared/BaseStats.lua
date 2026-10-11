-- BaseStats (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > BaseStats
-- Stats con las que arranca cada partida, antes del equipo, los talentos, las runas y las
-- habilidades. Está en Shared porque las usa el servidor (PlayerData.newStats) y también la
-- pantalla de Equipo, que muestra tus stats finales con el mismo cálculo que el servidor.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerCfg = Config.Player

local BaseStats = {}

function BaseStats.new()
	return {
		walkSpeed = PlayerCfg.WalkSpeed,
		dashCooldown = Config.Dash.Cooldown,
		burnBonus = 0,
		damage = Config.Projectile.Damage,
		attackInterval = PlayerCfg.AttackInterval,
		maxHealth = PlayerCfg.MaxHealth,
		frontArrows = 0,
		diagonalPairs = 0,
		pierce = 0,
		ricochet = 0,
		burn = false,
		critChance = PlayerCfg.CritChance,
		critMultiplier = PlayerCfg.CritMultiplier,
		pickupRadius = PlayerCfg.PickupRadius,
		lightningBolts = 0,
		meteors = 0,
		poison = 0,
		goldBonus = 0,
		startChoices = 0,
		rerolls = 0,
		stacks = {},
	}
end

return BaseStats
