# Arquero Coop

Roguelite de acción cooperativo para Roblox (1 a 4 jugadores), inspirado en las mecánicas de Archero 2 con contenido propio: disparás caminando, esquivás patrones de enemigos, elegís 1 de 3 habilidades al subir de nivel y peleás contra jefes con fases.

**Estado:** objetos temporales y etapa 7 implementados (inventario, equipo, mejoras, fusión y conjuntos). Análisis de continuidad en [ANALISIS_DEL_PROYECTO.md](ANALISIS_DEL_PROYECTO.md). Detalle de cada etapa en [CHANGELOG.md](CHANGELOG.md), lo que sigue en [ROADMAP.md](ROADMAP.md) y cómo está armado en [ARCHITECTURE.md](ARCHITECTURE.md).

## Qué hay hoy

- **Lobby** seguro con interfaz propia: equipo con quién está listo, capítulos con desbloqueo, botón **JUGAR**, cuenta regresiva de 5 s y accesos a inventario, equipamiento y tienda (Inventario y Equipo activos; Tienda pendiente).
- **Ciclo de partida** controlado por el servidor: `LOBBY → PREPARING → STARTING → PLAYING → RESULTS → RETURNING`.
- **3 capítulos**: Bosque Maldito (disponible), Ruinas Perdidas y Fortaleza Demoníaca (se desbloquean ganando el anterior).
- **Perfil guardado** (DataStore): capítulos desbloqueados, récords, estadísticas y monedas: oro 💰, gemas 💎 y piedras de mejora 🔷.
- **Botín** al matar enemigos (oro, y a veces gemas y piedras) y **números flotantes** de daño hecho, daño recibido, XP y botín.
- **Recompensas** al terminar la partida: oro por oleada superada (también si perdés), oro y piedras por cada jefe, y al ganar oro y gemas (más gemas la primera vez).
- **Combate**: 10 oleadas generadas al azar por capítulo, 40 enemigos y jefes con comportamientos (embestidas, áreas, rebotes, zigzag, teletransporte, enterrarse, invocar), mini-jefe y jefe con 2 fases.
- **Habilidades**: 11 con rarezas, elegir 1 de 3 al subir de nivel (XP compartida).
- **Cooperativo**: derribo, rescate de 3 s, eliminación, reaparición en el descanso y dificultad según 1 a 4 jugadores.
- **Mapa abierto**: una arena con relieve por partida, descanso de 4 s entre oleadas. Puertas opcionales con `Config.Waves.UseDoors`.
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

## Mapa abierto con relieve

Cada partida se juega en un mapa grande (300 × 300) de día, con lomas, **mesetas con rampa para subir**, montañas en el borde, bruma a lo lejos y árboles o ruinas repartidos. Los enemigos caminan sobre el relieve, los proyectiles suben y bajan con las colinas y los cofres y orbes quedan apoyados en el piso. Ya no hay puertas entre oleadas: al terminar una, a los 4 s arranca la siguiente.

Ajustes en `Config.Map` (tamaño de lomas, cantidad y altura de mesetas, montañas del borde, decoración, materiales por capítulo) y `Config.Arena.Size`. Con `Config.Waves.UseDoors = true` vuelven las puertas (y cada sala es un mapa nuevo).

## Modo frenético: qué probar

1. **Play** y JUGAR: la arena tiene luz de día y relieve. Caminá: **disparás mientras te movés**.
2. Las hordas se te vienen encima. Al pegar, el enemigo destella blanco y retrocede; los críticos salen con un número amarillo enorme y un sacudón.
3. Al morir explotan en partículas y sueltan **orbes de XP**: pasá cerca y vuelan hacia vos. A la derecha sube el **combo**.
4. Cada tanto aparece un **cofre** con un haz del color de su rareza: pasá al lado para abrirlo (objeto temporal para cada participante, monedas y posibilidad de equipo).
5. Si ves un enemigo **dorado**, matalo: botín enorme.
6. Al subir de nivel, destello dorado y cartas que giran como tragamonedas.

Ajustes en `Config.Frenzy` (hordas, dorados, cofres, combo), `Config.Player` (críticos, imán, disparar caminando), `Config.Effects` (luz, bloom, sacudón, calidad) y los sonidos en `Shared/Sounds.lua`.

**Sonidos mejores:** los que vienen son básicos de Roblox. En Studio, **Caja de herramientas › Audio**, buscá por ejemplo "coin", "explosion", "level up", "whoosh"; clic derecho en el que te guste › **Copiar ID del recurso** y pegalo en `Sounds.lua` como `"rbxassetid://NÚMERO"`.

## Objetos temporales, rarezas y dash

Los cofres, dorados y jefes entregan objetos acumulables. Botas, imán, corazón, colmillo y lente mejoran stats; ascua da un aura; bobina encadena rayos; pólvora convierte bajas en explosiones; reloj reduce recarga; prisma mítico duplica aura/rayos y añade explosiones. Fuego + pólvora potencia la explosión. Se borran al volver al lobby; no van al perfil.

Colores: común gris, poco común verde, rara azul, épica violeta, legendaria dorada, **mítica arcoíris animado**. Avisos de hallazgo, cartas, inventario y cofres usan la misma definición en `Rarities.lua`. Los avisos de peligro siguen identificando ataques enemigos; las balas enemigas usan rosa/rojo para distinguirlas de tus rayos y aura (`Config.EnemyProjectile.UseDangerColor`).

Las habilidades aparecen en cartas grandes centradas, con cursor libre y selección por **1 / 2 / 3** o clic/tap. **Toda la partida se pausa mientras cualquier participante vivo elige**: jugadores inmóviles, enemigos y proyectiles detenidos, sin daño. En cooperativo se reanuda cuando todos terminan; quien ya eligió ve un aviso de espera. Hay 30 segundos para elegir; después decide el servidor. El modo sin pausa sigue disponible desactivando `Config.Progression.PauseWhileChoosing` y `ChoosingShield`.

**Dash:** Shift en teclado, B en mando y botón DASH en móvil. Usa la dirección de movimiento o la mirada; impulso de 0,2 s con protección y 3,5 s de recarga base. Lo valida el servidor, que controla temporalmente la física. Ajustes en `Config.Dash`.

## Etapa 7: inventario y equipo

En el lobby abrí **Inventario** o **Equipo**. Cada perfil recibe una vez seis piezas comunes equipadas. Los jefes dan una pieza a cada participante; cofres y dorados tienen posibilidad de darla. Hay dos conjuntos (Cazador y Brasas), seis rarezas y seis espacios: arma, casco, armadura, anillo, amuleto y botas.

- **Equipar / Quitar:** sólo en el lobby y sin estar LISTO. Los bonos se aplican al comenzar la partida.
- **Mejorar:** hasta nivel 10; nivel actual × 60 oro y nivel actual en piedras por mejora. El costo se muestra antes de pulsar.
- **Fusionar:** tres del mismo tipo y rareza. Dos clics confirman el consumo de las dos piezas adicionales. Conserva el nivel mayor, el objeto principal y su espacio equipado; sube una rareza. Mítica es la máxima.
- **Conjuntos:** 3 Cazador: +10% imán; 6: +3 puntos de crítico. 3 Brasas: +15% daño de quemadura; 6: fuego desde el inicio.

Los bonos de equipo tienen topes para conservar el peso de las decisiones temporales. Inventario máximo: 150. El reciclaje queda para la economía de etapa 8. Guarda con el mismo DataStore de etapa 6; el perfil pasa a versión 2 sin reiniciar monedas o capítulos. En Studio sin acceso a DataStore es temporal, igual que antes.

Para probar: abrí el inventario, quitá y equipá una pieza; ganá un jefe, mejorá con sus recompensas, reuní tres piezas iguales y fusioná; detené y volvé a jugar para comprobar persistencia. Para un hallazgo mítico controlado, ejecutá en la **barra de comandos del servidor durante Play**:

```lua
local p = game.Players:GetPlayers()[1]
require(game.ServerScriptService.Server.ItemService).grant(p, "Prism") -- durante la partida
require(game.ServerScriptService.Server.Equipment).grant(p, "HunterBow", "Mythic")
```

Para medir FPS y presupuesto, activá `Config.Debug.ShowPerformance` antes de Play. No subas el límite de enemigos sin comprobar solo, cooperativo y móvil.

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
| `test_orbs.luau` | Orbes de XP (imán, aspiradora, tope, envío a los clientes) y cofres (cuándo aparecen, tope, abrir, abrir al final) |
| `test_selection_pause.luau` | Pausa global, inmovilidad, inmunidad, proyectiles, quemaduras, espera cooperativa y limpieza |
| `test_equipment.luau` | Equipo inicial, validaciones, costos, fusión, topes, persistencia y reparación de perfiles |
| `test_items_dash.luau` | Acumulación, aura, rayos, explosiones, sinergias, modo opcional sin pausa, dash, invocaciones y limpieza |
| `test_map.luau` | Relieve: misma semilla mismo mapa, centro plano, montañas en el borde, mesetas con rampa caminable, altura del piso, decoración, mapa hecho a mano, enemigos apoyados y a buena distancia |
| `test_rooms.luau` | Puerta entre oleadas: hay que entrar todos, límite de tiempo, cambio de sala, entrada, salas hechas a mano, más enemigos por oleada, decoración en los bordes |
| `test_integration.luau` | Dos partidas completas con el `GameServer` real y 2 bots desde el lobby |

Para correrlas necesitás Python y `luau` ([descarga](https://github.com/luau-lang/luau/releases)):

```
python tests/run.py                # todas
python tests/run.py match          # una sola
```

Prueban la **lógica**. La física, la red, la interfaz y los ProximityPrompt reales solo se ven en Studio.

## Cómo se agrega contenido

### Un mapa esculpido a mano

El mapa se genera solo en cada partida (lomas, mesetas con rampa, montañas en el borde, árboles), pero podés esculpir uno propio con el **Editor de terreno** de Studio y el juego lo usa en vez del generado:

1. En Studio (modo edición, sin Play), abrí **Editor de terreno** y esculpí dentro de un cuadrado de **300 × 300** centrado en el origen (X y Z de -150 a 150). Dejá el **centro casi plano** (ahí se aparece) y poné montañas o paredes en el borde. Para subir a lugares altos, hacé rampas: los jugadores trepan pendientes y saltan, pero no paredes verticales.
2. Abrí **Vista › Barra de comandos** y pegá esto (cambiá `forest` por `ruins` o `fortress` según el capítulo):

```lua
local maps = game.ServerStorage:FindFirstChild("Maps") or Instance.new("Folder", game.ServerStorage); maps.Name = "Maps"
local set = maps:FindFirstChild("forest") or Instance.new("Folder", maps); set.Name = "forest"
local min, max = Vector3int16.new(-38, -4, -38), Vector3int16.new(37, 17, 37)
local t = workspace.Terrain:CopyRegion(Region3int16.new(min, max)); t.Name = "Terrain"
t:SetAttribute("Corner", Vector3.new(min.X, min.Y, min.Z)); t.Parent = set
```

3. Opcional: decoración (árboles, ruinas, luces) como **Models** anclados, dentro de la misma carpeta `ServerStorage > Maps > forest`.
4. Dale Play: el juego pega tu terreno y mide su altura para que los enemigos caminen sobre él.

Notas: los enemigos **no usan física**: siguen la altura del piso y atraviesan la decoración. Cada partida borra el terreno del Workspace y pega el mapa (el tuyo queda guardado en ServerStorage). ServerStorage no lo sincroniza Rojo: guardalo con el place.

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
