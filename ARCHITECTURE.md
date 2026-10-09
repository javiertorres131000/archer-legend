# Arquitectura

Cómo está armado el juego. Para jugar o probar, ver el [README](README.md).

## Principios

- **El servidor manda.** Combate, daño, XP, habilidades, estados de vida y de partida se deciden en el servidor. Los clientes dibujan y piden.
- **Una sola puerta por responsabilidad.** Un único módulo daña jugadores (`PlayerLife.damage`), un único módulo cambia el estado de la partida (`MatchManager`), un único módulo sabe qué capítulos tiene cada uno (`ChapterUnlocks`), un único módulo toca DataStore (`Profiles`).
- **Contenido como datos.** Enemigos, jefes, capítulos, habilidades y balance viven en tablas (`Data/EnemyTypes`, `Chapters`, `Skills`, `Config`). Agregar contenido casi nunca requiere programar.
- **Estado replicado por atributos.** El servidor publica estado en atributos (`GameState` y cada `Player`); los clientes los leen. Los RemoteEvents se usan para eventos puntuales (proyectiles, ofertas, resultados) y para pedidos del cliente.

## Mapa de módulos

Rojo: `src/shared` → `ReplicatedStorage.Shared` · `src/server` → `ServerScriptService.Server` · `src/client` → `StarterPlayer.StarterPlayerScripts.Client` · `src/character/Health.server.lua` → `StarterPlayer.StarterCharacterScripts.Health`.

### Compartido (`src/shared`)

| Módulo | Responsabilidad |
| --- | --- |
| `Config` | Todos los números de balance, lobby, partida, coop, UI y debug |
| `Chapters` | Capítulos: presentación (Id, nombre, descripción, ícono, desbloqueo) y generación de oleadas |
| `Skills` | Habilidades de partida y rarezas |
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
| `PlayerData` | Stats, habilidades y estadísticas por jugador; `inMatch` |
| `PlayerLife` ★ | Ciclo de vida: aparición (lobby o arena), daño, derribo, rescate, eliminación |
| `Waves` | Genera y corre las oleadas del capítulo; escalado por jugadores |
| `Enemies` / `EnemyAI` | Registro de enemigos y su cerebro por comportamientos |
| `Combat` | Disparo automático (en primera persona, solo a lo que está delante), flechas del jugador y proyectiles enemigos |
| `Hazards` | Avisos y zonas en el piso |
| `Boss` | Publica la barra del jefe |
| `Progression` | XP compartida, niveles y ofertas de habilidades (solo participantes) |
| `Arena` | Piso, paredes, salas (decoración por código o Models de `ServerStorage > Rooms > <capítulo>`), puerta y puntos de aparición en la entrada |
| `Remotes` | RemoteEvents y carpeta `GameState` |
| `Data/EnemyTypes` | Catálogo de 35 enemigos y jefes |

★ = escrito en `--!strict`. Los módulos de IA y enemigos usan modo normal: sus tablas de ataques son muy variables y tiparlas no suma seguridad real (deuda técnica anotada).

### Cliente (`src/client`)

| Script | Responsabilidad |
| --- | --- |
| `LobbyUI` | Interfaz del lobby. Desactiva las interfaces por defecto de Roblox que reemplaza (lista de jugadores, vida, mochila) |
| `Hud` | Interfaz de combate (solo en partida): oleada, XP, jefe, habilidades, derribo, compañeros, vida, resultados, puerta y fundido de sala |
| `ScreenEffects` | Efectos de pantalla solo visuales (calculados en el cliente): alerta de amenazas fuera de la vista, destello rojo al recibir daño y sangre en los bordes según la vida |
| `CameraController` | Tercera persona en el lobby; en la partida primera persona o cenital según `Config.Camera.Mode`; desde arriba siguiendo a un compañero si estás eliminado |
| `ProjectileVisuals` | Dibuja los proyectiles con la misma cuenta que el servidor |

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
Cada `Player`: `Ready`, `InMatch`, `UnlockedChapters`, `ChapterRecords`, `ProfileStatus`, `Gold`, `Gems`, `Stones`, `LifeState`, `DownedLeft`, `ReviveProgress`, `RevivedBy`.

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

- Enemigos: Parts anclados sin Humanoid, movidos juntos con `BulkMoveTo`.
- Proyectiles: matemática en el servidor; el cliente solo dibuja y recibe eventos al disparar, rebotar y terminar.
- Interfaz: se redibuja por cambios de atributos, no cada frame (salvo la cuenta regresiva visible).
- Conexiones: las escuchas por jugador se desconectan cuando el jugador se va; los derribos limpian sus conexiones.

## Pruebas

`tests/run.py` copia los módulos a `tests/.build`, cambia los `require` de Roblox por rutas de archivo, inyecta `tests/mocks.luau` (imitación mínima de la API) y corre cada `test_*.luau` con `luau`. Cubren la lógica del servidor. La interfaz, la física y la red se prueban en Studio.

## Deuda técnica conocida

- `EnemyAI`, `Enemies` y los datos de enemigos en modo no estricto.
- Los proyectiles visuales se crean y destruyen (sin pool). Para muchas balas en móvil conviene un pool.
- Las piedras de mejora y las gemas todavía no se gastan en nada (llegan con equipamiento y tienda).
- Las pruebas del perfil corren sin hilos reales: los casos con dos pedidos a la vez se simulan con `onCall` del DataStore falso. Conviene probar en Studio con dos servidores.
- Enemigos con formas básicas (sin modelos ni animaciones).
