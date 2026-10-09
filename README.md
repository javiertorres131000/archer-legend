# Arquero Coop

Roguelite de acción cooperativo para Roblox (1 a 4 jugadores), inspirado en las mecánicas de Archero 2 con contenido propio: te quedás quieto para disparar, esquivás patrones de enemigos, elegís 1 de 3 habilidades al subir de nivel y peleás contra jefes con fases.

**Estado:** etapa 6, progresión permanente (perfil guardado, monedas y recompensas). Detalle de cada etapa en [CHANGELOG.md](CHANGELOG.md), lo que sigue en [ROADMAP.md](ROADMAP.md) y cómo está armado en [ARCHITECTURE.md](ARCHITECTURE.md).

## Qué hay hoy

- **Lobby** seguro con interfaz propia: equipo con quién está listo, capítulos con desbloqueo, botón **JUGAR**, cuenta regresiva de 5 s y accesos a inventario, equipamiento y tienda (bloqueados hasta que existan).
- **Ciclo de partida** controlado por el servidor: `LOBBY → PREPARING → STARTING → PLAYING → RESULTS → RETURNING`.
- **3 capítulos**: Bosque Maldito (disponible), Ruinas Perdidas y Fortaleza Demoníaca (se desbloquean ganando el anterior).
- **Perfil guardado** (DataStore): capítulos desbloqueados, récords, estadísticas y monedas: oro 💰, gemas 💎 y piedras de mejora 🔷.
- **Botín** al matar enemigos (oro, y a veces gemas y piedras) y **números flotantes** de daño hecho, daño recibido, XP y botín.
- **Recompensas** al terminar la partida: oro por oleada superada (también si perdés), oro y piedras por cada jefe, y al ganar oro y gemas (más gemas la primera vez).
- **Combate**: 10 oleadas generadas al azar por capítulo, 25 enemigos con comportamientos (embestidas, áreas, rebotes, zigzag, teletransporte, enterrarse, invocar), mini-jefe y jefe con 2 fases.
- **Habilidades**: 8 con rarezas, elegir 1 de 3 al subir de nivel (XP compartida).
- **Cooperativo**: derribo, rescate de 3 s, eliminación, reaparición en el descanso y dificultad según 1 a 4 jugadores.
- **Salas y puertas**: al terminar cada oleada se abre una puerta; cuando entra todo el equipo (o a los 40 s) pasan a una sala nueva con otra decoración.
- **Alerta de amenazas** en primera persona: flechitas rojas alrededor de la mira hacia enemigos cercanos que no estás viendo.

## Cómo correrlo

1. `rojo serve` en esta carpeta y **Connect** desde el plugin de Rojo en Studio.
2. En **Game Settings › Places › Max Players** poné **4** (el juego arma equipos de hasta 4).
3. **Play** (F5) para uno solo, o **Test › Clients and Servers › 2 Players › Start** para cooperativo.

**Cámara:** la arena se juega en primera persona. Para volver a la vista desde arriba: `Config.Camera.Mode = "TopDown"`. En primera persona el disparo automático apunta a lo que tenés delante (ancho del cono en `Config.Player.AimConeFirstPerson`).

Para probar rápido: `Config.Debug.UnlockAllChapters = true` deja elegir cualquier capítulo y `Config.Debug.StartWave` arranca en otra oleada (por ejemplo 10 para ir directo al jefe). Volvé a `false` y `1` para jugar normal.

## Guardado (etapa 6): cómo activarlo en Studio

El juego guarda con DataStore, y Roblox solo lo permite en Studio si el juego está publicado:

1. **File › Publish to Roblox** (puede quedar privado).
2. **Game Settings › Security** → activá **Enable Studio Access to API Services** → Save.

Sin esos dos pasos se juega igual, pero arriba a la derecha del lobby dice *"⚠ Sin guardado"* y nada queda guardado. Con ellos dice *"✔ Progreso guardado"*.

**Cómo probarlo:**
1. **Play**, jugá el Bosque Maldito y perdé en alguna oleada: en los resultados aparece *RECOMPENSAS* con el oro. Volvé al lobby: arriba a la derecha está el oro sumado y la tarjeta del capítulo dice "Mejor: oleada N/10".
2. Ganalo (más rápido con `Config.Debug.StartWave = 10`): oro, gemas (55 la primera vez) y piedras, *¡PRIMERA VICTORIA!* y el capítulo 2 desbloqueado.
3. **Stop** y **Play** de nuevo: tenés que seguir con las monedas, el capítulo 2 y el "✔ Ganado 1 vez".
4. Las recompensas se ajustan en `Chapters.lua › Rewards` de cada capítulo; el guardado en `Config.Profiles`.

Para empezar de cero en las pruebas, cambiá `Config.Profiles.StoreName` (por ejemplo a `"PlayerProfiles_test2"`): los perfiles viejos quedan guardados aparte. **No lo cambies en el juego publicado** o todos empiezan de cero.

## Cómo probar el botín y los números

1. **Play** y JUGAR. Al pegarle a un enemigo aparece el daño encima (blanco; amarillo si es fuerte). Con la habilidad de fuego, la quemadura sale en naranja.
2. Al matarlo: "+N XP" celeste y monedas que saltan y vuelan hacia vos con "+N 💰". Arriba a la derecha sube el contador del botín de la partida.
3. Dejate pegar: números rojos suben desde tu barra de vida.
4. En los resultados, al lado de RECOMPENSAS figura el botín juntado. En el lobby, el oro total ya lo incluye.

## Cómo probar salas, puertas y la alerta

1. **Play**, JUGAR. Aparecés en la entrada (sur) mirando hacia la pared norte, con decoración en los bordes.
2. Dejá que un enemigo se te ponga atrás o al costado: aparece una flechita roja alrededor de la mira apuntando hacia él. Al girar y verlo, desaparece.
3. Al terminar la oleada: se abre la puerta dorada al norte con el cartel "▶ PUERTA" y el HUD dice "¡Andá a la puerta! (0/1) · 40 s". Parate sobre el círculo dorado: fundido "Sala 2", aparecés en la entrada con otra decoración y arranca la oleada siguiente.
4. Con dos jugadores: si entra uno solo, el contador dice (1/2) y no pasa nada hasta que entra el otro o se acaba el tiempo.

Efectos de pantalla: con un enemigo atrás, además de la flecha brilla el borde de la pantalla de ese lado. Al recibir un golpe la pantalla se pone roja, y con poca vida los bordes se llenan de sangre (con menos del 30%, late). Se ajustan en `Config.Effects`.

Valores para ajustar en `Config`: `Waves.EnemyCountMultiplier` (cantidad de enemigos), `Enemy.MaxAlive`, `Waves.UseDoors`, `Rooms.DoorTimeout`, `Rooms.PropsPerRoom`, `Camera.ThreatRadius`, `Camera.ThreatViewAngle`.

## Cómo probar la etapa 5 con dos jugadores en Studio

1. **Test › Clients and Servers**, **2 Players**, **Start**. Se abren la ventana del servidor y dos de jugador (Player1 y Player2).
2. **Lobby:** las dos ventanas aparecen en una plaza de piedra con columnas y un portal dorado, con la interfaz del lobby. No arranca ninguna oleada sola. En el panel *Equipo* figuran los dos, Player1 con la corona (líder).
3. **Capítulos:** solo *Bosque Maldito* está disponible; los otros dos tienen candado. En la ventana de Player2, tocá un capítulo: aparece el aviso "Solo el líder del equipo elige el capítulo".
4. **Listo y cancelar:** en Player1 tocá **JUGAR**. Queda en *LISTO* y abajo dice "Esperando a que todos estén listos (1/2)". Volvé a tocarlo para cancelar.
5. **Cuenta regresiva:** poné listos a los dos. Aparece el 5-4-3-2-1 grande. Cancelá en una ventana antes de que termine: la cuenta se corta. Volvé a poner listos a los dos y dejala terminar.
6. **Partida:** pantalla de transición, los dos aparecen en la arena con la cámara desde arriba, el HUD de combate y la barra de vida propia. La barra superior dice "2 jugadores".
7. **Volver:** al ganar o perder sale la pantalla de resultados. **Volver al lobby** en las dos ventanas los lleva antes; si no, vuelven solos a los 15 s. Ya en el lobby, la interfaz aparece de nuevo y pueden preparar otra partida.
8. **Desconexión:** en otra prueba, con la cuenta corriendo, cerrá la ventana de Player2. La cuenta sigue con Player1 solo y la partida arranca para 1.

Para la **victoria** sin jugar 10 oleadas: `Config.Debug.StartWave = 10`. Al ganar se desbloquea *Ruinas Perdidas* para esta sesión.
Cosas que **no** se pueden armar fácil en Studio porque los jugadores de prueba arrancan juntos: entrar al servidor con una partida ya en curso. Está cubierto por las pruebas automáticas.

Si algo falla, el error queda en la ventana **Output** y en los logs de Studio.

## Cómo probar el cooperativo (etapa 4)

Con dos jugadores dentro de una partida:

1. **Derribo:** dejá que un jugador llegue a 0 de vida. Queda en el piso, en rojo, con "¡AYUDA!" y dos barras; no dispara y los enemigos lo ignoran.
2. **Rescate:** con el otro, acercate y mantené **E** 3 s. Vuelve con 40% de vida y escudo; el reloj de derribo no baja mientras lo rescatás.
3. **Cancelar:** empezá a rescatar y alejate antes de 3 s. No tiene que revivir.
4. **Eliminado:** dejá pasar 15 s sin rescatar. Esa ventana mira al compañero hasta el próximo descanso, donde reaparece en la arena.
5. **Derrota:** que caigan los dos. Sale la pantalla de derrota y vuelven al lobby.

## Pruebas automáticas

En `tests/` (fuera de lo que sincroniza Rojo). Corren los módulos reales del servidor sobre una imitación mínima de Roblox:

| Prueba | Qué cubre |
| --- | --- |
| `test_match.luau` | Ciclo de partida: solo, dos jugadores, cancelar listo, desconexión en la cuenta, victoria y vuelta, derrota y vuelta, segunda partida, partidas duplicadas, líder, equipo lleno, permisos y peticiones inválidas; recompensas entregadas y guardadas, volver a entrar con todo, no poder ponerse listo mientras carga el perfil |
| `test_playerlife.luau` | Derribo, rescate, eliminación, descanso, lobby a salvo, entradas y salidas |
| `test_catalog.luau` | Catálogo de enemigos y capítulos, escalado coop de oleadas, variedad |
| `test_aim.luau` | Puntería: en primera persona solo apunta adelante; en cenital, a todo alrededor |
| `test_ai.luau` | 60 s de cada enemigo y jefe: sin errores, todos atacan, los jefes cambian de fase |
| `test_profiles.luau` | Perfil: nuevo, guardar y volver, monedas, reintentos, DataStore caído, Studio sin acceso, bloqueo de sesión (esperar, tomar, abandonado, perdido, mismo servidor), migraciones, datos rotos, versión nueva, irse mientras carga, guardado automático y cierre del servidor |
| `test_rewards.luau` | Cálculo de recompensas: derrota, jefes, primera victoria, valores fuera de rango, los tres capítulos |
| `test_loot.luau` | Botín por enemigo y jefe, multiplicador del capítulo, variación; números flotantes agrupados, quemadura, daño recibido, XP y frecuencia de envío |
| `test_rooms.luau` | Puerta entre oleadas: hay que entrar todos, límite de tiempo, cambio de sala, entrada, salas hechas a mano, más enemigos por oleada, decoración en los bordes |
| `test_integration.luau` | Dos partidas completas con el `GameServer` real y 2 bots desde el lobby |

Para correrlas necesitás Python y `luau` ([descarga](https://github.com/luau-lang/luau/releases)):

```
python tests/run.py                # todas
python tests/run.py match          # una sola
```

Prueban la **lógica**. La física, la red, la interfaz y los ProximityPrompt reales solo se ven en Studio.

## Cómo se agrega contenido

### Una sala modelada a mano

La decoración por código está bien para probar, pero las salas lindas se modelan en Studio:

1. En el Explorer, dentro de **ServerStorage**, creá una carpeta **Rooms** y adentro una carpeta con el `Id` del capítulo: `forest`, `ruins` o `fortress`.
2. Armá la sala en el Workspace como un **Model** (árboles, ruinas, luces, lo que quieras) y movelo a esa carpeta. Se usa uno por sala en orden alfabético (`Sala1`, `Sala2`...), y vuelve a empezar si hay menos modelos que oleadas.
3. El modelo se pone tal cual está, así que armalo **sobre la arena**: el centro es (0, 0, 0), el piso está en Y = 0 y mide 120 × 120 (de -60 a 60). La puerta está en el norte (Z = -60) y la entrada en el sur (Z = 60); dejá esas dos zonas y el centro libres.
4. Todo anclado (`Anchored`). Ojo: los enemigos **atraviesan** la decoración (no usan física), así que conviene que sea decorativa y vaya pegada a las paredes.

Como la carpeta está en ServerStorage (fuera de lo que sincroniza Rojo), guardala con el place o exportala como `.rbxm`.

### Un enemigo
Una entrada en `src/server/Data/EnemyTypes.lua` combinando comportamientos, y sumarlo al `Pool` de un capítulo:

```lua
T.IceGolem = {
	Name = "Gólem de hielo", Health = 150, Size = 3.6, Color = C(150, 210, 255),
	ContactDamage = 14, XP = 4, Cost = 4,
	Move = { Type = "Keep", Speed = 6, Min = 14, Max = 26 },
	Attacks = {
		{ Type = "Shoot", Cooldown = { 2, 3 }, Range = 45, Telegraph = 0.6,
		  Count = 4, Spread = 50, Bounces = 1, Speed = 30, Damage = 12, Color = C(150, 210, 255) },
	},
}
```

**Movimientos:** `Chase` (persigue), `Erratic` (a saltitos), `Keep` (mantiene distancia), `Wander` (deambula), `Still` (quieto).

**Ataques:**

| Tipo | Qué hace | Campos propios |
| --- | --- | --- |
| `Dash` | Marca una franja y embiste | `Distance`, `Speed`, `Damage` |
| `Shoot` | Dispara proyectiles | `Pattern` (`Aimed`/`Radial`/`Random`), `Count`, `Spread`, `Bursts`, `BurstDelay`, `Rotate`, `AimLine`, `Track`, `Jitter`, `Jump`, `Bounces`, `Zigzag = {Amp, Freq}`, `Return`, `SpeedSeq`, `Size`, `Color`, `Lifetime` |
| `Area` | Círculos que se llenan y explotan | `Target` (`Player`/`Self`/`Random`), `Count`, `Scatter`, `FirstExact`, `Radius`, `Delay`, `Bursts`, `Zone = {Duration, Dps}`, `WarnColor` |
| `Breath` | Chorro de proyectiles en cono | `Duration`, `Rate`, `Spread`, `TurnRate` o `Spin` |
| `Teleport` | Marca un destino y aparece ahí | `Distance` |
| `Burrow` | Se entierra y sale cerca del jugador | `Duration`, `Emerge` |
| `Summon` | Invoca enemigos | `Spawn`, `Count`, `Max` |

Comunes a todos: `Cooldown`, `Range`, `MinRange`, `Weight`, `Telegraph`, `Recover`, `Repeats` + `RepeatTelegraph`, `Then` (encadena otro ataque), `ChainRest`.

Pueden ser rango `{min, max}`: `Cooldown`, `Telegraph`, `RepeatTelegraph`, `Recover`, `ChainRest`, `Distance`, `Speed`, `Damage`, `Count`, `Bursts`, `BurstDelay`, `Repeats`, `Radius`, `Delay`, `Scatter`, `Duration`, `Emerge`, `Rotate`.

### Un jefe
Igual que un enemigo pero con `Boss = true` y `Phases`, cada una con su `Move`, `Attacks` y `Rest`. `Above = 0.5` = esa fase dura mientras tenga más del 50% de vida.

### Un capítulo
Una entrada en `src/shared/Chapters.lua`: `Id` estable, nombre, descripción e ícono para el lobby, `UnlockedByDefault` o `Requires` (el `Id` del capítulo que hay que ganar), colores, `Pool` de enemigos (con `From` = oleada en que aparecen), `MiniBoss`, `Boss`, multiplicadores y presupuesto.
