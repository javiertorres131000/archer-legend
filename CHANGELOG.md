# Cambios

## 2026-10-10 · Árbol de talentos y nivel de cuenta

- La lista de 8 talentos pasa a ser un **árbol radial**: núcleo y tres ramas (Ataque, Defensa, Utilidad), 25 nodos, 8 nodos clave. Solo se desbloquea lo conectado.
- **Nivel de cuenta:** XP al terminar cada partida (oleadas, bajas con tope, jefes, victoria, × capítulo). Cada nivel da 1 punto y pide más XP que el anterior. Se muestra en los resultados.
- **Costo progresivo:** puntos por nivel + oro que sube 6 % por cada punto gastado; gemas en dos nodos clave. Árbol completo: 103 puntos y ~1.000.000 de oro.
- **Reiniciar árbol:** devuelve puntos, no oro.
- Interfaz nueva con líneas, nodos que brillan por rama, disponibles que laten, detalle del nodo y diseño para pantallas angostas.
- Perfil v4 (`Account`); los talentos de la v3 se borran. La reconciliación vacía el árbol si hay más puntos gastados que los del nivel.

## 2026-10-10 · Etapa 8a: talentos y reciclaje + arreglos

- **Disparo:** siempre automático y caminando. Se quitó el apuntado manual con **Q** (`SetAimMode`, `Config.Player.DefaultAimMode`, `AimToggleKeys`, `ShootWhileMoving`, `StillThreshold`); chocaba con el modo frenético y rompía `test_aim`.
- **Combat:** la quemadura valida que el estado del dueño exista antes de leer `burnBonus` (aviso de tipos de la línea 215; un jugador que se va con flechas en el aire ya no rompe nada).
- **Cursor:** en primera persona dentro de la arena el mouse se oculta, como en Megabonk. Reaparece al elegir habilidad, en resultados o al quedar eliminado.
- **Talentos permanentes** (botón ⭐ Talentos del lobby): Fuerza, Vitalidad, Precisión, Agilidad, Magnetismo y Codicia (oro); Ventaja y Otra mano (gemas). Se compran en el lobby, se validan en el servidor y se aplican al empezar cada partida.
- **Ventaja:** empezás con 1–2 elecciones de habilidad gratis. **Otra mano:** botón 🎲 para cambiar las cartas, con cambios limitados por partida. **Codicia:** más oro solo para quien la tiene.
- **Reciclaje de equipo:** por pieza (doble toque) o en lote para comunes y poco comunes. Nunca toca lo equipado. Devuelve oro por rareza + 40 % del oro y 50 % de las piedras invertidas en mejoras.
- **Perfil v3** (`Talents`); migración sin pérdida desde v2. La reconciliación borra talentos inexistentes y recorta niveles al máximo.
- Pruebas nuevas: `test_talents.luau` y casos de reciclaje en `test_equipment.luau` (16/16 archivos OK).

## 2026-10-09 · Corrección de selección de poderes

- Cartas grandes centradas, fondo oscuro y cursor libre automáticamente.
- Pausa global mientras cualquier jugador vivo elige; inmovilidad de todos los participantes, sin daño, proyectiles o enemigos avanzando.
- Relojes de quemadura, rescate y combate suspendidos; aviso cooperativo de espera y selección automática a los 30 segundos.
- Nueva prueba de regresión para pausa, inmunidad, proyectiles, reanudación y limpieza.


## 2026-10-09 · Objetos temporales y etapa 7

- Diez pasivos acumulables de partida con aura, rayos encadenados, explosiones y sinergias; reinicio sin guardarlos en el perfil.
- Rarezas compartidas de común a mítica; avisos y cofres por color, arcoíris animado en míticos.
- Elección compacta sin pausa ni bloqueo del disparo; dash con validación, recarga e impulso controlado por el servidor.
- Cinco roles nuevos: esqueleto de horda, bestia veloz, mago encapuchado, caballero pesado y capitán élite; introducción progresiva en los tres capítulos.
- Inventario guardado, seis espacios, equipo inicial, botín de jefes/dorados/cofres, mejoras con oro y piedras, fusión y dos conjuntos.
- Perfil v2 compatible con el progreso anterior; peticiones y transacciones validadas en servidor.
- Límite de enemigos incluye grupos e invocaciones; separación espacial y pool de proyectiles visuales; diagnóstico FPS optativo.
- Nuevas pruebas de objetos, dash, equipo y persistencia. Compilación de todo el código y revisión de documentación.


## Mapa abierto con relieve, de día

- **De día:** luz natural, bloom suave, sin líneas neón, y bruma a lo lejos (`Config.Effects`).
- **Mapa abierto grande** (300 × 300) por partida, sin puertas entre oleadas (`Config.Waves.UseDoors = false`; con `true` vuelven).
- **Relieve generado** (`MapBuilder.lua`) con el Terreno de Roblox: lomas suaves, **mesetas con rampa** para subir, acantilados de roca, montañas en el borde y un centro plano para aparecer. Distinto en cada partida. Pasto, arenisca o basalto según el capítulo.
- **Mapas esculpidos a mano:** un TerrainRegion en `ServerStorage > Maps > <capítulo>` reemplaza al generado (pasos en el README).
- **`Ground.lua`:** altura del piso en una grilla. Los enemigos caminan sobre el relieve, y los avisos del piso, orbes, cofres y puntos de aparición quedan apoyados.
- Los enemigos aparecen a 32–75 studs de algún jugador (en un mapa grande no tiene sentido que aparezcan del otro lado). Los cofres aparecen cerca del equipo.
- Los que vuelven en el descanso aparecen al lado de un compañero.
- Un enemigo no te pega por contacto si estás arriba de una meseta (o abajo).
- Las flechas y bolas se dibujan siguiendo el relieve.
- Prueba nueva `test_map.luau`. `test_rooms` ahora prueba el modo con puertas activándolo.

**Cambios en lo existente (y por qué)**
- `Arena`: ya no hay piso plano visible ni paredes a la vista (son invisibles; el borde son montañas). La decoración por salas (`ServerStorage > Rooms`) se reemplazó por mapas (`ServerStorage > Maps`).
- Se aparece en el centro del mapa, no en la entrada sur.

## Modo frenético

El juego pasa de "Archero" (quieto para disparar) a un survivors frenético tipo Megabonk.

**Ritmo**
- **Disparás caminando** (`Config.Player.ShootWhileMoving`; en `false` vuelve la regla de quedarse quieto).
- **Hordas:** 10 veces más enemigos por oleada, aparecen de a 5 y mucho más seguido; hasta 110 a la vez. Cada enemigo común tiene 60% de la vida y hace 50% del daño (son muchos más).
- **Pausa entre golpes** de 0,3 s: con hordas, no te pegan diez en el mismo instante.
- **Críticos** (10%, ×2) y **retroceso** de los enemigos al recibir flechazos.
- **Enemigo dorado** (0,8%): brilla, aguanta ×4 y suelta ×6 de botín, gemas y mucha XP.
- **Orbes de XP:** la XP ya no llega sola, cae en orbes que atraés con un imán al pasar cerca. Al terminar la oleada se juntan todos solos.
- **Cofres** cada 45 muertes del equipo: se abren pasando al lado y dan oro, a veces gemas y **una habilidad gratis a cada jugador**. Haz de luz dorado para encontrarlos.
- **Habilidades nuevas:** Imán (+40% radio), Ojo de halcón (+8% crítico) y Golpe brutal (+50% daño crítico).
- Barras de vida solo en jefes y dorados (con hordas pesaban; el daño se ve con los números).
- XP por nivel ajustada (`BaseXP` 12, `XPGrowth` 7): en una partida se sube unos 20 niveles.

**Jugo y luces**
- Destello blanco del enemigo al recibir un golpe, explosión de partículas del color del enemigo al morir y onda expansiva.
- Números de crítico enormes con "!", sacudón de cámara en críticos, golpes recibidos y dorados.
- **Contador de combo** con anuncios: ¡BUENA RACHA!, ¡MASACRE!, ¡IMPARABLE!, ¡LEYENDA!
- **Subir de nivel:** destello dorado, "¡NIVEL N!" y cartas que entran girando como tragamonedas, con el borde latiendo según la rareza.
- **Luz de arena:** de noche, con bloom y más saturación, teñida con el color del capítulo; líneas neón en las paredes. Flechas con estela, proyectiles enemigos con luz.
- Calidad automática (`Config.Effects.Quality`): en celulares, sin bloom, sin estelas y con menos partículas.

**Sonido**
- `Sfx.client.lua` y `Sounds.lua`: disparo, golpe, crítico, muerte, monedas (más agudas si las juntás seguido), XP, daño recibido, subir de nivel, cofre y puerta. Por ahora usan sonidos básicos de Roblox; se reemplazan en `Sounds.lua`.

**Cambios en lo existente (y por qué)**
- `Combat` ya no exige estar quieto; sortea críticos y empuja a los enemigos.
- `Run`: la XP cae como orbe; cada muerte cuenta para los cofres y manda una explosión a todos. Al empezar el descanso se juntan los orbes y se abren los cofres.
- `PlayerLife.damage` respeta la pausa entre golpes.
- `CombatFeed`: tipos nuevos "crit" y "kill"; los golpes llevan la parte del enemigo (para el destello); la XP es la de los orbes que juntaste.
- En vista desde arriba, el personaje ya no se gira hacia el objetivo mientras camina.
- Pruebas nuevas `test_orbs.luau`; `test_aim`, `test_loot`, `test_playerlife` e integración actualizadas.

## Botín y números flotantes

- **Botín al matar enemigos** (`Loot.lua`): cada enemigo suelta oro según su costo (±50%) y a veces una gema (3%) o una piedra de mejora (2%). Los jefes sueltan un extra. Se multiplica por `Rewards.LootMult` del capítulo (1 · 1,6 · 2,5). Lo cobran **todos** los participantes (botín compartido) y va directo al perfil: no se pierde si perdés o te vas. Los invocados por jefes no dan botín.
- **Números flotantes** (`CombatFeed.lua` en el servidor, `CombatText.client.lua` en el cliente): el daño que hacés sobre el enemigo (blanco; amarillo y grande desde 40), la quemadura en naranja, el daño que recibís en rojo sobre tu barra de vida, "+N XP" al matar y "+N 💰" con monedas que vuelan hacia vos.
- Contador del botín de la partida arriba a la derecha del HUD, y "Botín" en la pantalla de resultados.
- Para no cargar la red, el servidor junta los golpes al mismo enemigo y manda todo cada 0,1 s (`Config.CombatText.FlushInterval`).
- Ajustes en `Config.Loot` y `Config.CombatText` (con `ShowTeammateDamage = true` también ves el daño de tus compañeros, en gris).
- Prueba nueva `test_loot.luau`.

**Cambios en lo existente (y por qué)**
- `Enemies.damage` recibe el tipo de daño ("hit" o "burn") para mostrar la quemadura distinta.
- `PlayerLife.damage` avisa a `CombatFeed` el daño recibido (sigue siendo la única puerta de daño a jugadores).
- Las recompensas de fin de partida no cambiaron: el botín es aparte y se suma a ellas.

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
