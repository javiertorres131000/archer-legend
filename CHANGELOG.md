# Cambios

## Etapa 6: progresión permanente

**Nuevo**
- `Profiles.lua`: perfil de cada jugador guardado con DataStore (capítulos, récords, estadísticas y monedas). Reintentos con espera creciente, sesión bloqueada (un perfil abierto en un solo servidor a la vez, con Id por sesión), versiones con migraciones, reparación de datos rotos, guardado automático cada 60 s, al terminar la partida, al salir y al cerrar el servidor.
- Sin DataStore (Studio sin acceso a las APIs, `Config.Profiles.Enabled = false` o Roblox caído) se juega con un perfil temporal que nunca se escribe, con aviso en el lobby.
- Monedas: oro, gemas y piedras de mejora (`Currencies.lua`, compartido). Se ven arriba a la derecha del lobby.
- `Rewards.lua`: recompensas calculadas en el servidor con lo que pasó en la partida. Valores por capítulo en `Chapters.lua › Rewards`. Pantalla de resultados con las recompensas y "¡PRIMERA VICTORIA!".
- Tarjetas de capítulo con récord: "✔ Ganado N veces" o "Mejor: oleada N/10".
- Pruebas nuevas `test_profiles.luau` y `test_rewards.luau`, DataStore simulado en `mocks.luau`.

**Cambios en lo existente (y por qué)**
- `ChapterUnlocks` ahora lee y escribe el perfil (antes vivía en memoria). Mientras el perfil carga solo está el capítulo inicial; al cargar se actualiza solo.
- No te podés poner LISTO mientras se carga tu perfil (aviso "Cargando tu perfil…"), así las recompensas siempre tienen dónde guardarse.
- El resumen de la partida suma `wavesCleared`, `bossesKilled` y, para cada jugador, `rewards` y `firstClear`.
- Los mocks de prueba: `task.wait` hace avanzar el reloj, hay `os.time`, `game.JobId`, `BindToClose`, `Player:Kick`, `HttpService` y DataStore en memoria con fallas a pedido.

## Efectos de pantalla: amenazas que brillan, golpe y sangre

- **Alerta de amenazas más visible:** las flechas ahora son más grandes, tienen halo y laten. Además, el borde de la pantalla se enciende en rojo del lado de la amenaza (izquierda, derecha o abajo si está atrás).
- **Golpe:** al recibir daño la pantalla se pone roja y se va apagando. Cuanto más daño, más rojo.
- **Sangre por vida baja:** con menos del 80% de vida los bordes se empiezan a llenar de sangre, y la sangre avanza hacia el centro y aparecen manchas a medida que baja. Con menos del 30% (o derribado), la sangre late como un corazón.
- Todo vive en un script nuevo, `ScreenEffects.client.lua` (la alerta se movió desde `Hud`). Se ajusta en `Config.Effects`. Son solo visuales: no cambian nada del servidor.

## Salas, puertas, más enemigos y alerta de amenazas

**Nuevo**
- **Puerta entre oleadas:** al terminar una oleada se abre una puerta dorada en la pared norte (con cartel "▶ PUERTA" visible a través de las paredes). Cuando todos los que están en pie se paran en ella, el equipo pasa a la sala siguiente y aparece en la entrada del sur; la oleada arranca 1,2 s después. Si alguien no va, a los 40 s pasan todos igual (`Config.Rooms.DoorTimeout`).
- **Salas distintas:** cada sala cambia el tono de colores y la decoración (árboles y rocas en el bosque, columnas rotas en las ruinas, braseros y pinchos en la fortaleza), siempre pegada a las paredes para dejar el centro libre. El piso usa un material por capítulo (pasto, adoquín, basalto).
- **Salas hechas a mano (opcional):** si en Studio ponés Models en `ServerStorage > Rooms > <Id del capítulo>` (por ejemplo `Rooms > forest`), se usan esos en vez de la decoración por código, uno por sala, en orden alfabético.
- **Alerta de amenazas (primera persona):** flechitas rojas alrededor de la mira que apuntan hacia enemigos (a menos de 20 studs) o proyectiles enemigos (a menos de 14) que no estás viendo. Más cerca = más grande y opaca.
- HUD: "¡Andá a la puerta! (1/2) · 35 s" durante el descanso y un fundido "Sala N" al cambiar de sala.
- Prueba nueva `test_rooms.luau`.

**Cambios en lo existente (y por qué)**
- **50% más enemigos por oleada** (`Config.Waves.EnemyCountMultiplier = 1.5`, multiplica el presupuesto de cada oleada) y el tope de enemigos vivos a la vez sube a **35** (`Config.Enemy.MaxAlive`).
- El descanso ya no dura un tiempo fijo: termina cuando el equipo cruza la puerta. Con `Config.Waves.UseDoors = false` vuelve el comportamiento anterior (`BreakTime` segundos, misma sala).
- Los jugadores ya no aparecen en el centro sino en la entrada del sur, mirando hacia la puerta.
- Los derribados se levantan y los eliminados reaparecen al empezar el descanso, como antes, pero ahora en la entrada.

## Cámara en primera persona

- La arena se juega en **primera persona** (`Config.Camera.Mode = "FirstPerson"`). La cámara cenital original sigue disponible con `"TopDown"`.
- En primera persona el disparo automático apunta solo a enemigos **delante** del jugador (cono de `Config.Player.AimConeFirstPerson` = 110°). Sigue disparando solo estando quieto.
- El lobby sigue en tercera persona; si quedás eliminado, mirás a un compañero desde arriba.
- Mira en el centro de la pantalla; el mouse se libera en el menú de habilidades y en los resultados.
- Prueba nueva `test_aim.luau`.

## Etapa 5: lobby y sistema de partidas

**Nuevo**
- Lobby físico (`Lobby.lua`): plaza de piedra con detalles dorados, columnas, portal y el único punto de aparición del juego.
- Ciclo de partida en el servidor (`MatchManager.lua`): LOBBY, PREPARING, STARTING, PLAYING, RESULTS y RETURNING. Listo y cancelar, cuenta regresiva de 5 s, líder que elige capítulo, una sola partida por servidor y validación de todos los pedidos.
- `Run.lua`: prepara, avanza y limpia una partida reutilizando el motor de combate existente.
- `ChapterUnlocks.lua`: desbloqueo de capítulos por jugador (en memoria; se guarda en la etapa 6).
- Interfaz del lobby (`LobbyUI.client.lua`) con tema de fantasía oscura y dorado (`UITheme.lua`): equipo, capítulos, JUGAR/LISTO, cuenta regresiva animada, avisos, transiciones y botones de inventario, equipamiento y tienda deshabilitados.
- Barra de vida propia en el HUD.
- Pruebas `test_match.luau` (ciclo de partida) y documentos ROADMAP, ARCHITECTURE y CHANGELOG.

**Cambios en lo existente (y por qué)**
- Las oleadas ya no arrancan solas al entrar: arrancan cuando el equipo está listo.
- Capítulos renombrados a Bosque Maldito, Ruinas Perdidas y Fortaleza Demoníaca, con `Id`, descripción, ícono y desbloqueo. Se movieron de `src/server/Data` a `src/shared` para que el lobby los muestre sin duplicar datos.
- Ganar ya no pasa automáticamente al capítulo siguiente: lo desbloquea y el líder lo elige en el lobby.
- `PlayerLife` distingue participantes (`inMatch`) de quienes están en el lobby. Solo los participantes reciben daño y cuentan para la derrota y el escalado.
- Se quitó el estado `SPECTATING` (entrar a mitad de oleada): ahora quien entra con una partida en curso espera en el lobby y juega la siguiente. El espectador de los eliminados sigue igual.
- Las habilidades solo se ofrecen a participantes.
- Resultados: "Volver al lobby" (antes "Jugar de nuevo"). Vuelven todos al votar o a los 15 s.
- Cámara normal de Roblox en el lobby; cenital en la arena.
- Se desactivan la lista de jugadores, la barra de vida y la mochila de Roblox (las reemplazan las propias).
- `Config.Run` pasó a `Config.Match`; `Config.Debug.StartChapter` se reemplazó por `Config.Debug.UnlockAllChapters`.

## Etapa 4: cooperativo

- Derribo (15 s), rescate manteniendo E 3 s con validación en el servidor, eliminación y reaparición en el descanso.
- `PlayerLife.lua` como única forma de dañar jugadores.
- Dificultad según 1 a 4 jugadores (vida, cantidad de enemigos y XP por nivel), fijada al empezar cada oleada.
- Sin regeneración de vida de Roblox ni botón de reiniciar personaje.
- Pruebas automáticas en `tests/`.

## Etapa 3.5: enemigos estilo Archero

- Sistema de comportamientos (`EnemyAI.lua`): movimientos, 7 tipos de ataque, fases, combos y rangos aleatorios.
- 25 enemigos y 6 jefes; 3 capítulos con oleadas generadas al azar.
- Proyectiles con rebote, zigzag y boomerang; avisos y zonas en el piso (`Hazards.lua`).

## Etapa 3: jefes y resultados

- Jefes con patrones y furia, derrota, espectador, reaparición en el descanso y pantalla de resultados.

## Etapa 2: oleadas y habilidades

- Oleadas, XP compartida, elegir 1 de 3 habilidades con rarezas, pausa de equipo al elegir.

## Etapa 1: base de combate

- Arena, cámara cenital, disparo automático estando quieto, enemigos, proyectiles simulados en el servidor.
