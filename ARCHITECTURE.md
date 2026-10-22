# Arquitectura

Cómo está armado el juego. Para jugar o probar, ver el [README](README.md).

## Principios

- **El servidor manda.** Combate, daño, XP, habilidades, estados de vida y de partida se deciden en el servidor. Los clientes dibujan y piden.
- **Una sola puerta por responsabilidad.** Un único módulo daña jugadores (`PlayerLife.damage`), un único módulo cambia el estado de la partida (`MatchManager`), un único módulo sabe qué capítulos tiene cada uno (`ChapterUnlocks`), un único módulo toca DataStore (`Profiles`), un único módulo procesa compras con Robux (`Receipts`).
- **Contenido como datos.** Enemigos, jefes, capítulos, habilidades y balance viven en tablas (`Data/EnemyTypes`, `Chapters`, `Skills`, `Config`). Agregar contenido casi nunca requiere programar.
- **Estado replicado por atributos.** El servidor publica estado en atributos (`GameState` y cada `Player`); los clientes los leen. Los RemoteEvents se usan para eventos puntuales (proyectiles, ofertas, resultados) y para pedidos del cliente.

## Mapa de módulos

Rojo: `src/shared` → `ReplicatedStorage.Shared` · `src/server` → `ServerScriptService.Server` · `src/client` → `StarterPlayer.StarterPlayerScripts.Client` · `src/character/Health.server.lua` → `StarterPlayer.StarterCharacterScripts.Health`.

### Compartido (`src/shared`)

| Módulo | Responsabilidad |
| --- | --- |
| `Config` | Todos los números de balance, lobby, partida, coop, UI y debug |
| `Chapters` | Capítulos: presentación (Id, nombre, descripción, ícono, desbloqueo) y generación de oleadas |
| `Skills` | Once habilidades de partida |
| `Rarities` | Rarezas y colores comunes; mítico arcoíris |
| `RunItems` | Diez objetos temporales, límites y efectos sobre stats |
| `EquipmentDefs` | Seis espacios, dos conjuntos, costos, valor de reciclaje y topes de equipo |
| `Talents` | Árbol de talentos: nodos, conexiones, posición, costos (puntos/oro/gemas), `check` compartido y XP de cuenta |
| `Crates` | Las 5 cajas: precio, colores y tabla de premios con probabilidades; `rates`, `pick` (tirada ponderada) y formatos |
| `CrateItems` | Rarezas de las cajas (Common → Secret) y los premios (tipo, rareza y aspecto) |
| `CrateModels` | Piezas 3D con Parts: hexágonos, antorchas, cofres y premios de bloques (o modelos propios de `CrateAssets`) |
| `SkinFx` | Colores y efectos de cada skin (paleta para pisadas/aura y flechas propias); `get` y `forCharacter` (atributo `CrateLook`) |
| `CrateLooks` | Trajes detallados de premios de personaje (piezas por segmento): se aplican al avatar R15 y a las vistas previas |
| `CratePlazaLayout` | Dónde va la plaza de las cajas y cada plataforma (servidor y cliente calculan igual) |
| `UITheme` | Colores, tipografías, íconos y constructores de UI (fantasía oscura y dorado) |

### Servidor (`src/server`)

| Módulo | Responsabilidad |
| --- | --- |
| `GameServer` (Script) | Punto de entrada: arma todo y llama a `MatchManager.update` cada frame |
| `MatchManager` ★ | Ciclo de partida, listo/cancelar, líder, capítulo, cuenta regresiva, resultados, vuelta. Valida todos los pedidos del lobby |
| `Run` | Una partida en la arena: preparar, avanzar frame a frame, resumen, limpiar. Reutiliza el motor de combate |
| `Lobby` ★ | Construye la zona segura y el único `SpawnLocation` |
| `ChapterUnlocks` ★ | Capítulos desbloqueados y récords por jugador (sobre el perfil) |
| `Profiles` ★ | Perfil guardado con DataStore: carga, guardado, bloqueo de sesión, versiones, monedas |
| `Rewards` ★ | Calcula y entrega las recompensas al terminar la partida |
| `Loot` ★ | Botín de cada enemigo al morir: lo sortea y lo cobra cada participante |
| `Orbs` ★ | Orbes de XP: dónde están, quién los junta (imán) y aspiradora al final de la oleada |
| `Chests` ★ | Cofres con rareza: aparecen cada tantas muertes, se abren por cercanía |
| `CombatFeed` ★ | Junta los números flotantes de cada jugador y los manda agrupados cada 0,1 s |
| `ItemService` | Entrega de objetos temporales; aura, rayos y explosiones calculados en servidor |
| `Equipment` | Inventario permanente, equipar, mejorar, fusionar, reciclar, botín y base de stats |
| `EnemyVisuals` | Aspecto de los enemigos: modelo de `ServerStorage/EnemyModels` soldado a la caja (sin scripts) u ojos |
| `WeaponService` | Arma elegida (perfil), validación en el lobby y `stats.weapon` al empezar |
| `StatsBreakdown` | Desglose de stats por sistema (base, equipo, talentos, runas, ahora) para el panel |
| `RunLog` | Registro de partidas: fila por jugador, DataStore aparte por día y resumen por capítulo |
| `DebugCommands` | Comandos del panel de prueba; permiso: Studio o `Config.Debug.Admins` |
| `TalentService` | Compra y reinicio validados del árbol (`TalentRequest`/`TalentState`) y aplicación al empezar |
| `Dash` | Validación, recarga, protección e impulso con propiedad física del servidor |
| `Grab` | Agarre del Atrapador: ancla al jugador, daño por tick, suelta por daño al agarrador / forcejeo (`Remotes.StruggleRequest`, con tope de frecuencia) / derribo / tiempo; anota quién lo salvó (atributos `Grabbed`, `GrabProgress`, `SavedBy`, `Rescued`) |
| `PlayerData` | Stats, habilidades y estadísticas por jugador; `inMatch` |
| `PlayerLife` ★ | Ciclo de vida: aparición (lobby o arena), daño, derribo, rescate, eliminación |
| `Waves` | Genera y corre las oleadas del capítulo; escalado por jugadores; cada aparición se reparte en varios lados alrededor de un jugador (`Enemies.findSpawnPositionAt`), a veces por su espalda |
| `Enemies` / `EnemyAI` | Registro de enemigos y su cerebro por comportamientos |
| `Combat` | Ataque del jugador: manual (`setTrigger` valida apretado + dirección desde `Remotes.AttackRequest`, con límite de mensajes; cadencia y daño en el servidor) o automático según `Config.Player.FireMode`; flechas del jugador y proyectiles enemigos |
| `Hazards` | Avisos y zonas en el piso |
| `Boss` | Publica la barra del jefe |
| `Progression` | XP compartida, niveles y ofertas de habilidades (solo participantes); carta dorada (`offerGolden`: el servidor la elige y aplica la habilidad 2 veces) |
| `Arena` | Bordes, piso de seguridad, arma el mapa (vía `MapBuilder`), puntos de aparición en el centro y la puerta (modo opcional) |
| `MapBuilder` ★ | Terreno con relieve generado (lomas, mesetas con rampa, montañas) o pegado de un mapa hecho a mano; reparte la decoración |
| `Ground` ★ | Altura del piso en una grilla interpolada (la usan enemigos, avisos, orbes, cofres y apariciones) |
| `Remotes` | RemoteEvents, la RemoteFunction `CrateRequest` y carpeta `GameState` |
| `CratePlaza` | Construye la plaza volcánica: piso, lava, muros, arco y una plataforma por caja con cofre, antorchas, cartel y ProximityPrompt |
| `Receipts` | Único dueño de `MarketplaceService.ProcessReceipt`: cada sistema registra su Developer Product; confirma solo lo entregado y guardado |
| `CrateEquip` | Premios equipados (mascota y personaje): validación, bono de daño de la mascota y aspecto del avatar con HumanoidDescription |
| `CrateService` | Compra y apertura de cajas: valida todo, cobra, tira el premio y lo guarda en el perfil; leaderstats y monedas de prueba |
| `Data/EnemyTypes` | Catálogo de 40 enemigos y jefes, con cinco roles nuevos |

★ = escrito en `--!strict`. Los módulos de IA y enemigos usan modo normal: sus tablas de ataques son muy variables y tiparlas no suma seguridad real (deuda técnica anotada).

### Cliente (`src/client`)

| Script | Responsabilidad |
| --- | --- |
| `LobbyUI` | Interfaz del lobby. Desactiva las interfaces por defecto de Roblox que reemplaza (lista de jugadores, vida, mochila) |
| `Hud` | Interfaz de combate (solo en partida): oleada, XP, jefe, habilidades, derribo, compañeros, vida, resultados, puerta y fundido de sala |
| `ScreenEffects` | Efectos de pantalla solo visuales (calculados en el cliente): alerta de amenazas fuera de la vista, destello rojo al recibir daño y sangre en los bordes según la vida |
| `CameraController` | Tercera persona en el lobby; en la partida primera persona o cenital según `Config.Camera.Mode`; desde arriba siguiendo a un compañero si estás eliminado |
| `CombatText` | Números flotantes (daño hecho y recibido, XP, botín) y monedas que vuelan al jugador. Solo visual |
| `Juice` | Destello de golpes, explosiones, sacudón, combo (atributos locales `Combo` y `BestCombo`), pausa de impacto (`HitStopUntil`, acercamiento y destello) y subida de nivel |
| `Pickups` | Dibuja orbes de XP (y su vuelo al jugador) y adorna los cofres |
| `Atmosphere` | Luz de día, bloom suave, bruma y tinte del capítulo; luz y cielo volcánicos en la plaza de las cajas |
| `Sfx` | Sonidos (definidos en `Shared/Sounds.lua`), con mínimo de tiempo entre repeticiones; nota ascendente por racha y redoble antes de una legendaria (`LegendaryReveal`) |
| `ProjectileVisuals` | Dibuja los proyectiles; pools separados de flechas y balas enemigas. Las flechas de quien tiene una skin con `Arrow` las viste `SkinArrowFx` |
| `SkinArrowFx` | Flechas con la skin del arquero: vara, punta, estela, llamas, brasas y luz en vuelo; chispazo al disparar y explosión al pegar (tope de luces, calidad baja) |
| `EquipmentUI` | Inventario, espacios, mejoras, confirmación de fusión y reciclaje |
| `WeaponUI` / `MeleeVisuals` | Elegir arma en el lobby y dibujar los golpes cuerpo a cuerpo |
| `StatsUI` | Panel de stats (lobby y Tab en partida) |
| `DebugPanel` | Panel de prueba F2 (solo si el servidor marcó `DebugAllowed`) |
| `TalentsUI` | Árbol de talentos del lobby: nodos, líneas, detalle (solo muestra y pide) |
| `RewardsUI` / `RarityVisuals` | Avisos por rareza, arcoíris y lista de pasivos |
| `Dash` (cliente) | Teclado, mando, botón táctil y recarga visible |
| `CrateUI` | Menú CRATES (Shop Crates / Index, DROP RATES); pide abrir y arranca la animación; hace flotar los cofres de la plaza |
| `PetFollow` | Dibuja la mascota equipada de cada jugador siguiéndolo (solo visual) |
| `EggCinematic` | Animación de abrir un huevo (pantalla completa): sacudón, "RARE SIGNAL", ruptura, columna de luz con silueta y reveal |
| `CrateCinematic` | Animación de apertura en una arena local: caída, temblor, explosión, ruleta, reveal y limpieza |
| `EnemyAnimator` | Aleteo de las alas de los modelos de enemigos voladores (solo en pantalla, desactiva la soldadura localmente) |
| `GrabUI` | Pantalla de agarrado y forcejeo (ESPACIO / A / botón táctil), "¡AYUDA!" sobre el compañero agarrado y avisos de rescate |
| `AttackInput` | Ataque manual: click / R2 / botón ATACAR; manda apretado + dirección de la mira (o del mouse en cenital) al servidor |
| `ItemEffects` | Efectos de pasivos con límite por calidad |
| `Performance` | Diagnóstico optativo de FPS y presupuesto |

## Ciclo de partida (`MatchManager`)

```
LOBBY ──alguien listo──> PREPARING ──todos listos (o 4 listos)──> STARTING (5 s)
  ^                         ^  │                                    │
  │                         └──┴──── alguien cancela / entra uno ───┘
  │                                                                 │ termina la cuenta
  │                                                                 v
RETURNING <──15 s o todos votan── RESULTS <──victoria / derrota── PLAYING
  (PLAYING ──se fueron todos──> RETURNING, sin resultados)
```

- **Una partida por servidor.** `startMatch` solo corre desde `STARTING` y si `Run` no está activo. Arrancar dos veces es imposible.
- **Participantes**: los listos, por orden de llegada, hasta `Config.Match.MaxPartySize`. Quien entra con una partida en curso espera en el lobby.
- **Líder**: el que más tiempo lleva en el lobby. Si se va, pasa al siguiente. Solo el líder elige capítulo; cambiarlo pide confirmar de nuevo a todos.
- **Capítulo**: solo se puede elegir si **todos** los del lobby lo tienen desbloqueado. Si entra alguien que no lo tiene, vuelve al capítulo 1.
- **Desconexiones**: en preparación se recalcula (si los que quedan están todos listos, la cuenta sigue); en partida la cubre `PlayerLife` (derrota si no queda nadie en pie) y `Run` (sin participantes, vuelve al lobby); en resultados cuenta como voto para volver.

### Pedidos del cliente (`Remotes.LobbyRequest`)

| Acción | Argumento | Se acepta si |
| --- | --- | --- |
| `SetReady` | boolean | En LOBBY, PREPARING o STARTING; el jugador no está en partida; hay lugar; tiene el capítulo |
| `SelectChapter` | string (Id) | En preparación; es el líder; el capítulo existe y todos lo tienen |
| `ReturnToLobby` | — | En RESULTS; es participante; pasaron `MinResultsTime` segundos |

Todo pedido se descarta si el tipo es incorrecto o si llega antes de `Config.Match.RequestCooldown` desde el anterior del mismo jugador. Los rechazos con explicación se avisan por `Remotes.LobbyNotice`.

### Estado publicado

`GameState` (atributos): `MatchState`, `SelectedChapter`, `LeaderId`, `CountdownEnd` y `ResultsEnd` (hora de `workspace:GetServerTimeNow()`), y los de la partida (`Phase`, `Wave`, `Level`, `XP`, `Boss*`, `PartySize`, `Chapter*`, `RoomIndex`, `DoorEnd`, `DoorInside`, `DoorNeeded`).
Cada `Player`: `Ready`, `InMatch`, `UnlockedChapters`, `ChapterRecords`, `ProfileStatus`, `Gold`, `Gems`, `Stones`, `RunGold`, `RunGems`, `RunStones` (botín de la partida), `LifeState`, `DownedLeft`, `ReviveProgress`, `RevivedBy`.

## Perfil guardado (`Profiles`)

```
PlayerAdded ─task.spawn─> load: UpdateAsync toma el bloqueo { JobId, Session, Time }
   ├─ bloqueado por otra sesión → espera LockRetryDelay (LockRetries veces) y después lo toma
   ├─ bloqueo más viejo que LockExpire → lo toma enseguida (servidor caído)
   ├─ versión más nueva que la del servidor → se usa sin guardar
   └─ falla tras Retries intentos / Studio sin acceso → perfil temporal (Offline)
Ready → guardar: cada AutoSaveInterval, al terminar la partida (saveSoon), al salir (y soltar), BindToClose
```

- Solo escribe la sesión dueña del bloqueo (`Lock.Session`). Si otro la tomó, deja de guardar y saca al jugador, para no pisar datos más nuevos.
- Formato: `{ Version, Data, Lock }`. Al cargar: `migrate` (Migrations[n] lleva n → n+1) y `reconcile` (completa y repara campos). Las monedas salen de `Currencies.lua`.
- El cierre del servidor espera todos los guardados y cargas en curso (hasta `CloseTimeout`).
- Las recompensas las calcula `Rewards` con datos del servidor (oleadas superadas, jefes vencidos); el cliente solo las muestra.

## Salas y puertas (`Run.updateDoor`)

```
Wave ──todos muertos──> Break: se abre la puerta (DoorEnd = ahora + 40 s)
Break ──entran todos los que están en pie, o se acaba el tiempo──> sala siguiente:
       cierra la puerta, limpia proyectiles y zonas, Arena.buildRoom, lleva a todos a la entrada
       ──EnterDelay (1,2 s)──> Waves.nextWave
```

El servidor decide quién está en la puerta (`Arena.inDoorZone` sobre la posición del personaje); el cliente solo lo muestra. Con `Config.Waves.UseDoors = false`, `Waves` vuelve a usar el descanso por tiempo.

## Ciclo de vida de un jugador (`PlayerLife`)

```
ALIVE ──vida en 0──> DOWNED ──lo reviven (3 s)──> ALIVE
                       └──15 s sin rescate──> ELIMINATED ──descanso──> ALIVE
```

Solo los participantes (`inMatch`) reciben daño y cuentan para la derrota y el escalado. En el lobby nadie recibe daño; si alguien muere por otra causa ahí, reaparece a los 2 s.

## Rendimiento

Con el modo frenético hay hasta 110 enemigos y 200 orbes a la vez:
- Orbes y efectos (partículas, destellos, combo) existen solo en el cliente; el servidor manda eventos agrupados cada 0,1 s.
- Barras de vida solo en jefes y dorados. Luces en proyectiles con tope de 10.
- `FxQuality` baja los efectos en celulares (sin bloom ni estelas, menos partículas).
- La separación usa una grilla espacial con consultas vecinas. Los grupos y las invocaciones respetan el límite de 110; el número de enemigos por sí solo no garantiza fluidez.
- Los efectos de pasivos están limitados a 12 en calidad baja y 30 en alta; el daño siempre se calcula en servidor.
- `Config.Debug.ShowPerformance` habilita FPS, peor frame del segundo, enemigos y proyectiles para medir en Studio.

- Enemigos: Parts anclados sin Humanoid, movidos juntos con `BulkMoveTo`.
- Proyectiles: matemática en el servidor; el cliente solo dibuja y recibe eventos al disparar, rebotar y terminar.
- Interfaz: se redibuja por cambios de atributos, no cada frame (salvo la cuenta regresiva visible).
- Conexiones: las escuchas por jugador se desconectan cuando el jugador se va; los derribos limpian sus conexiones.

## Pruebas

`tests/run.py` copia los módulos a `tests/.build`, cambia los `require` de Roblox por rutas de archivo, inyecta `tests/mocks.luau` (imitación mínima de la API) y corre cada `test_*.luau` con `luau`. Cubren la lógica del servidor. La interfaz, la física y la red se prueban en Studio.

## Deuda técnica conocida

- `EnemyAI`, `Enemies` y los datos de enemigos en modo no estricto.
- Pools de proyectiles visuales implementados; falta medir red y FPS con cuatro jugadores en móvil.
- Oro y piedras se gastan en mejoras de equipo. Las gemas, el reciclaje y la tienda quedan para etapa 8.
- Las pruebas del perfil corren sin hilos reales: los casos con dos pedidos a la vez se simulan con `onCall` del DataStore falso. Conviene probar en Studio con dos servidores.
- Enemigos con formas básicas (sin modelos ni animaciones).

## Objetos, equipo y selección

`PlayerData.items` sólo dura la partida. `ItemService` valida límites, modifica stats y aplica daño de aura, rayos y explosiones. Las explosiones secundarias no generan más explosiones, para limitar cadenas y evitar recursión. Las recompensas de cofres son personales para cada participante; la XP sigue compartida.

`Profiles` v2 agrega `Inventory`, `Equipment` y `EquipmentInitialized`, preservando el StoreName y los datos previos. Reconcile valida IDs, rarezas, niveles, UIDs duplicados y correspondencia de espacios. `Equipment` sólo permite cambios en el lobby y sin LISTO; valida propiedad, recursos, rarezas y tres UIDs distintos para fusionar. Cobros y mutaciones no contienen yields. El cliente pide acciones y recibe snapshots.

`Profiles` v4 tiene `Talents` (nodo → rango) y `Account` (`Level`, `XP`); la migración 3 → 4 vacía los talentos viejos. Reconcile descarta ids desconocidos, recorta al máximo y vacía el árbol si se gastaron más puntos que los del nivel. `Rewards.grant` suma la XP de cuenta (`Profiles.addAccountXP`) y `MatchManager` la manda en los resultados. Los puntos no se guardan: se calculan (`pointsForLevel − spent`). `TalentService.buy` usa `Talents.check` (la misma regla que dibuja el cliente): perfil, lobby sin LISTO, frecuencia, conexión, máximo, puntos, oro y gemas; cobra y sube sin yields. `Reset` vacía el árbol sin devolver oro. Reciclar (`Recycle`, `RecycleRarity` sólo común/poco común) nunca toca piezas equipadas.

Al comenzar, `Run` crea stats nuevas y aplica el equipo y después los talentos, una vez, antes de reaparecer; luego da las elecciones gratis de Ventaja (`stats.startChoices`). `stats.rerolls` habilita `Remotes.RerollSkills`: el servidor valida offerId, vida y cambios restantes, y cambia el offerId para que una elección vieja no valga. Al terminar, limpia pasivos y ofertas. Por defecto elegir pausa a todo el equipo, inmoviliza personajes y suspende daño, enemigos, proyectiles y relojes de combate. Se reanuda cuando ningún participante vivo tiene ofertas pendientes; las cartas están centradas con cursor libre y atajos 1/2/3. El dash limita dirección y recarga, controla la física durante el impulso y devuelve la propiedad automática después.
