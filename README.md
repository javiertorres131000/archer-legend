# Arquero Coop

Roguelite de acción cooperativo para Roblox (1 a 4 jugadores), inspirado en las mecánicas de Archero 2 con contenido propio: disparás caminando, esquivás patrones de enemigos, elegís 1 de 3 habilidades al subir de nivel y peleás contra jefes con fases.

**Estado:** etapa 7 (equipo) y etapa 8a (árbol de talentos con nivel de cuenta y reciclaje) implementadas. Análisis de continuidad en [ANALISIS_DEL_PROYECTO.md](ANALISIS_DEL_PROYECTO.md). Detalle de cada etapa en [CHANGELOG.md](CHANGELOG.md), lo que sigue en [ROADMAP.md](ROADMAP.md) y cómo está armado en [ARCHITECTURE.md](ARCHITECTURE.md).

## Qué hay hoy

- **Lobby: la Ciudadela**, una plaza de castillo sobre una isla flotante, con portal de batalla, mercado con NPCs, vitrina de skins, tablas de récords y patio del tesoro (cajas). Hasta 20 jugadores, cada uno en su **grupo** (invitaciones y cola rápida **BUSCAR GRUPO**) que viaja a una **arena privada**. Tiene interfaz propia: grupo con quién está listo, capítulos con desbloqueo, botón **JUGAR**, cuenta regresiva de 5 s y accesos a Equipo, Talentos, Stats, Arma, **Tienda** y **Misiones**.
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
2. En **Game Settings › Places › Max Players** poné **20** en la Ciudadela (ver "Ciudadela y Arena" abajo; los grupos son de hasta 4).
3. **Play** (F5) para uno solo, o **Test › Clients and Servers › 2 Players › Start** para cooperativo.

**Cámara:** la arena se juega en primera persona; cada jugador puede pasar a tercera persona (detrás del hombro) y volver con la tecla **V** (o R3 en el joystick). Teclas, distancia y hombro en `Config.Camera`. Para volver a la vista desde arriba: `Config.Camera.Mode = "TopDown"`. **Ataque manual:** click izquierdo (R2 en el joystick, botón ATACAR en el celular) para atacar hacia donde apunta la mira; mantener apretado sigue atacando a la cadencia del arma, y un click durante la recarga sale apenas se pueda. Sirve para las tres armas y también caminando. En cenital se apunta con el mouse. Para volver al ataque automático: `Config.Player.FireMode = "Auto"` (ahí en primera persona apunta solo a lo que tenés delante, cono en `Config.Player.AimConeFirstPerson`). En primera persona el mouse no se ve dentro de la arena; aparece solo al elegir habilidad, en los resultados o al quedar eliminado.

Para probar rápido: `Config.Debug.UnlockAllChapters = true` deja elegir cualquier capítulo y `Config.Debug.StartWave` arranca en otra oleada (por ejemplo 10 para ir directo al jefe). Volvé a `false` y `1` para jugar normal.

## Ciudadela y Arena (dos places)

La Ciudadela (lobby) y la Arena son dos places de la misma experiencia, y los dos usan este mismo código. El rol lo decide `Server/Places` según el `PlaceId`. En Studio todo funciona en un solo place: los grupos juegan ahí mismo.

Para publicarlo:

1. En el Creator Hub, dentro de esta experiencia, **creá un place nuevo** para la Arena y copiá su ID.
2. Poné ese ID en `Config.Places.ArenaPlaceId` (en `src/shared/Config.lua`). `LobbyPlaceId` ya es el place actual.
3. **Ciudadela:** Game Settings › Places › Max Players **20**. **Arena:** Max Players **4**.
4. Publicá el código en **los dos** places: abrí cada uno en Studio, conectá Rojo y publicá. La Arena no lleva el modelo `Ciudadela` (sin él, se arma el lobby simple de siempre).

Cómo se juega: en la Ciudadela cada uno arranca en su grupo. **JUGAR** te pone listo y, cuando todo tu grupo lo está, viajan juntos a una arena privada. **＋ Invitar** suma amigos al grupo, y **BUSCAR GRUPO** (el líder) completa el grupo con otros jugadores del mismo capítulo. Ajustes en `Config.Places`: tiempo de invitación, espera máxima de la cola, espera en la arena y reintentos.

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

## Pasto

El pasto animado del terreno está más bajo (`Config.Map.GrassLength`, 0.35; Roblox trae 1). Solo se ve si el Terreno tiene *Decoration* activado en Studio.

## Mapa abierto con relieve

Cada partida se juega en un mapa grande (300 × 300) de día, con lomas, **mesetas con rampa para subir**, montañas en el borde, bruma a lo lejos y árboles o ruinas repartidos. Los enemigos caminan sobre el relieve, los proyectiles suben y bajan con las colinas y los cofres y orbes quedan apoyados en el piso. Ya no hay puertas entre oleadas: al terminar una, a los 4 s arranca la siguiente.

Ajustes en `Config.Map` (tamaño de lomas, cantidad y altura de mesetas, montañas del borde, decoración, materiales por capítulo) y `Config.Arena.Size`. Con `Config.Waves.UseDoors = true` vuelven las puertas (y cada sala es un mapa nuevo).

## Modo frenético: qué probar

1. **Play** y JUGAR: la arena tiene luz de día y relieve. Caminá: **disparás mientras te movés**.
2. Las hordas se te vienen encima **desde todos lados**: cada aparición se reparte en 3 grupos de direcciones distintas (que van rotando) y la mitad de las veces uno sale por tu espalda (`Config.Frenzy.SpawnSides`, `BehindSpawnChance`). Cada enemigo se acerca en curva con su propio ángulo, así te rodean en vez de hacer fila (`Config.Enemy.FlankAngle`, `FlankFar`, `FlankNear`). Al pegar, el enemigo destella blanco y retrocede; los críticos salen con un número amarillo enorme y un sacudón.
3. Al morir explotan en partículas y sueltan **orbes de XP**: pasá cerca y vuelan hacia vos. A la derecha sube el **combo**.
4. Cada tanto aparece un **cofre** con un haz del color de su rareza: pasá al lado para abrirlo (objeto temporal para cada participante, monedas y posibilidad de equipo).
5. Si ves un enemigo **dorado**, matalo: botín enorme.
6. Al subir de nivel, destello dorado y cartas que giran como tragamonedas. Los primeros 4 niveles salen rapidísimo (`Config.Progression.EarlyLevelMult`).
7. **Racha:** cada muerte seguida suena una nota más aguda (escala pentatónica, hasta 2 octavas); a los x10, x25, x50... sale un cartel y un arpegio. El contador, su barra y esos carteles van en arcoíris que corre de costado, más rápido cuanto más larga la racha.
8. **Pausa de impacto:** en tus críticos el arma se congela un instante, la cámara se acerca y la pantalla destella; con dorados y jefes, más fuerte (`Config.Effects.HitStop`, `HitStopGap`, `HitStopFov`).
9. **Legendaria:** si una de las cartas es legendaria, se hace esperar 1,6 s (signos de pregunta dorados que laten cada vez más rápido y redoble) y aparece con destello dorado y el cartel "¡LEGENDARIA!". Hasta que se revela no se puede elegir.
10. **Resultados:** las monedas cuentan hacia arriba, aparece "¡NUEVO RÉCORD!" o a cuánto quedaste de tu récord / de ganar, tu mejor racha y la barra de la cuenta ("te faltan X XP para el próximo punto de talento"). **⚡ ¡OTRA!** vuelve al lobby y te deja listo con el mismo capítulo; si todos los listos apretaron OTRA, la cuenta es de 3 s (`Config.Match.AgainCountdownTime`).
11. **Orbes en escalera:** juntá orbes seguidos y cada uno suena una nota más aguda; si pasa un rato sin juntar, arranca de nuevo (`Config.Effects.OrbLadderNotes`, `OrbLadderWindow`).
12. **Números con racha:** cuanto más larga la racha, más grandes salen tus números de daño (hasta +60% en x50, `Config.CombatText.ComboGrow`); los críticos, en arcoíris que gira.
13. **Carta dorada:** con 5% de chance (`Config.Progression.GoldenCardChance`) una carta de la oferta viene dorada (borde de oro que late, "✦ ×2"): da 2 niveles de esa habilidad de una vez. La decide el servidor.
14. **Sinergias:** al completar un par de habilidades que combinan (lista editable en `Shared/Synergies.lua`, ej. Perforación + Rebote = "Flecha imparable") sale "¡SINERGIA!" en arcoíris con los dos nombres, una vez por partida. Por ahora es solo el aviso, sin bono extra.

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

- **Reciclar:** el botón ♻ de cada pieza (dos toques) la convierte en oro y piedras; los botones de arriba reciclan todas las comunes o poco comunes **sin equipar**. Lo equipado nunca se recicla. Devuelve 20 oro × rango de rareza + 40 % del oro y 50 % de las piedras gastadas en mejorarla (y piedras extra desde poco común).

Los bonos de equipo tienen topes para conservar el peso de las decisiones temporales. Inventario máximo: 150. Guarda con el mismo DataStore de etapa 6; el perfil pasa a versión 2 sin reiniciar monedas o capítulos. En Studio sin acceso a DataStore es temporal, igual que antes.

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
7. **Volver:** al ganar o perder sale la pantalla de resultados. **Volver al lobby** (o **¡OTRA!**) en las dos ventanas los lleva antes; si no, vuelven solos a los 15 s. Con ¡OTRA! quedás listo solo al llegar. Ya en el lobby, la interfaz aparece de nuevo y pueden preparar otra partida.
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
6. **Agarre:** desde la oleada 3 aparece cada tanto el **Atrapador** (violeta). Parpadea, marca una franja en el piso y salta: si te alcanza, te agarra. No te movés, no atacás ni hacés dash, y te saca vida cada medio segundo; los demás enemigos te siguen pegando. Pantalla roja con "¡TE AGARRARON!" y barra de forcejeo.
   - **Rescate:** el compañero ve "¡AYUDA!" sobre tu cabeza (a través de todo); si le saca el 25% de la vida al Atrapador (o lo mata), te suelta: "¡Beto te salvó!" / "¡Salvaste a Ana!".
   - **Solo:** machacá **ESPACIO** (A en el joystick, botón ¡SOLTATE! en el celular) 16 veces. El servidor cuenta como mucho 12 toques por segundo.
   - Te suelta también si te derriban o a los 10 s. Al soltarte sale despedido, queda aturdido 1,5 s y no vuelve a agarrar por 6 s. Todo en `Config.Grab`.

## Árbol de talentos

En el lobby tocá **⭐ Talentos**: un núcleo arriba y tres ramas (**Ataque**, **Defensa** y **Utilidad**). Los círculos son nodos de stats con varios rangos y los rombos son **nodos clave** (flechas que perforan, fuego desde el inicio, flecha extra, +20 % vida, habilidades al empezar, cambio de cartas…). Solo se desbloquea un nodo **conectado** a otro que ya tenés.

Está pensado para que cueste:
- **Puntos:** 1 por cada **nivel de cuenta**. El nivel sube con la XP de cada partida (oleadas, bajas, jefes y victoria, × el multiplicador del capítulo), también si perdés. Cada nivel pide 100 XP más que el anterior (300, 400, 500…). La XP ganada se ve en la pantalla de resultados.
- **Oro:** cada punto cuesta un 6 % más que el anterior, cuente donde cuente (los primeros ~150; el punto 50 ~2.800; el 80 ~15.000). Tener mucho oro no alcanza: el freno principal al principio es el nivel.
- **Gemas:** Ventaja y Otra mano además piden gemas.
- El árbol completo son 103 puntos (nivel 103) y ~1.000.000 de oro.
- **Reiniciar árbol** (dos toques) devuelve todos los puntos, **no** el oro ni las gemas.

Todo se ajusta en `src/shared/Talents.lua` (`Talents.Config` y la lista de nodos con su posición X/Y en el dibujo). El perfil pasa a versión 4: los talentos de la lista anterior se borran (decidido así en desarrollo). Para probar rápido, en la barra de comandos del servidor durante Play:

```lua
local p = game.Players:GetPlayers()[1]
local P = require(game.ServerScriptService.Server.Profiles)
P.addAccountXP(p, 20000); P.addCurrency(p, "Gold", 50000); P.addCurrency(p, "Gems", 500)
```

## Enemigos: que vengan a vos y modelos

**Que vengan a vos** (`Config.Enemy`):
- Aparecen a 26–50 studs de algún jugador (antes 32–75).
- A más de 40 studs, todo el que camina (también los que deambulan o mantienen distancia) va directo al jugador más cercano y al menos a velocidad 14.
- Si alguno queda a más de 75 studs durante 3 segundos (o un quieto, como plantas y torretas, a más de 45), reaparece a distancia normal de alguien. Nunca hay que salir a buscar al último.

**Indicador sobre cada enemigo** (`EnemyMarkers`, `Config.Enemy.Markers`): un rombo brillante que se ve a través de paredes y relieve. Naranja los comunes, violeta las élites, dorado los dorados y rojo los jefes. Con 10 o menos por matar se agrandan y laten, y arriba de la pantalla aparece una flecha que apunta al más cercano, con cuántos quedan y a qué distancia. Los enterrados no se marcan.

**Bordes del mapa:** paredes invisibles de 260 studs de alto y 10 de grosor (el dash no las atraviesa), cruzadas en las esquinas, y un techo invisible. Además, cada 0,25 s el servidor revisa que ningún jugador haya quedado afuera o caído debajo del piso; si pasa, lo devuelve adentro, apoyado en el terreno (`Config.Arena.ReturnMargin`, `FallBelow`).

**Modelos** (`EnemyVisuals`). La caja de colisión sigue igual (el combate no cambia); el modelo se suelda encima.
1. En Studio, creá una carpeta **EnemyModels** dentro de **ServerStorage**.
2. Metele un **Model** por enemigo, llamado exactamente como el Id del tipo (lista abajo). También sirve uno para un grupo: **Redondos** (lo usan todos los enemigos redondos: slimes, murciélagos, bombas, espíritu, bestia y rey slime) o **Todos** (cualquiera sin modelo propio). Cada uno puede ser una **carpeta con varios Models**: cada tipo de enemigo usa siempre el mismo modelo de la carpeta. Además el modelo se tiñe con el color del enemigo (`Config.Enemy.ModelTint`), así se distinguen los tipos aunque compartan modelo. Los personajes con articulaciones (zombies, R6/R15) se animan: se rescata su animación de caminar aunque se borren sus scripts. Sirve uno de la **Caja de herramientas** (Toolbox › Creator Store) o uno hecho por ustedes.
3. Listo: se escala solo a la altura del enemigo, se apoya en el piso y mira para el mismo lado. Si mira para otro lado, poné al Model un atributo numérico **Yaw** (grados, p. ej. 180). Para agrandarlo o achicarlo, un atributo **Scale** (p. ej. 1.3).
4. **Seguridad:** los scripts que traiga el modelo se borran solos al usarlo (los modelos gratis a veces traen scripts maliciosos). Igual, revisalos antes de publicar.
5. **Animación (opcional):** si el modelo tiene un AnimationController o Humanoid y una **Animation** llamada `Walk` (o `Idle`), se reproduce en bucle.
6. Los modelos miden al menos `Config.Enemy.ModelMinHeight` (6 studs), para que los enemigos chicos no queden escondidos en el pasto. La barra de vida y el indicador van arriba del modelo.
7. Usá modelos livianos (pocas piezas o un MeshPart): puede haber más de 100 enemigos a la vez.

8. **Alas que aletean** (`EnemyAnimator`): si el modelo tiene sus alas dentro de un grupo con "wing" en el nombre (p. ej. `left wing` / `right wing`), aletean solas en la pantalla de cada jugador (`Config.Enemy.WingFlapAngle`, `WingFlapSpeed`). Los voladores (`Float` en `EnemyTypes`) además suben y bajan (`FlyBob`).

Los que no tienen modelo se ven como la figura de siempre, ahora con ojos (`Config.Enemy.Eyes`). Al arrancar, la Salida lista los tipos que todavía no tienen modelo. El parpadeo de ataque y la quemadura se ven como un brillo sobre el modelo.

Ids: GreenSlime, RedSlime, WhiteSkull, YellowSkull, GreenBat, RedBat, GreyWolf, BrownWolf, Snake, Spider, Crocodile, Worm, GreenPlant, BluePlant, GreenStump, BlueStump, Cactus, WhiteGolem, BlueGolem, SkeletonArcher, RedArcher, FireSpirit, TornadoMage, FireMage, WhiteBomb, BlueBomb, RedBomb, ElectricTower, OrbTower, HordeSkeleton, RushBeast, HoodMage, HeavyKnight, EliteCaptain y los jefes KingSlime, Treant, CyclopsMage, StoneGolem, Reaper, FlameDemon (el nombre de cada uno está en `src/server/Data/EnemyTypes.lua`).

## Armas: arco, espada y puños

En el lobby tocá **⚔️ Arma** y elegí (se guarda en el perfil; solo sin estar LISTO):
- **Arco:** a distancia, dispara hacia la mira.
- **Espada:** tajo hacia donde apuntás (alcance 11 studs), en arco en arco de 130° que pega a todos los de adelante. Daño ×1.9, más lenta (×1.3).
- **Puños:** alcance 7, arco 80°, muy rápidos (×0.45 del tiempo entre golpes) y daño ×0.75.

**Arma en primera persona** (`WeaponFx`, se apaga con `Config.Effects.FirstPersonWeapon = false`): estilo shooter de Roblox. El arco se ve solo (sin manos), apuntando al frente con la flecha hacia la mira; con espada y guantes, las manos en bloque de tu personaje (color de tus brazos) entran desde las esquinas de abajo y sostienen el ítem. Los modelos pueden ser un Model o una sola MeshPart. El arco va de frente, a la izquierda del centro e inclinado, con la flecha cargada que se tensa hacia vos, sale en cada disparo y se recarga; la espada abajo a la derecha (tajo de lado a lado, vuelta completa en el Torbellino); un guante a cada lado en guardia con golpes alternados. Balanceo al caminar y chispas del color del arma donde pegás. Modelos en `ReplicatedStorage > WeaponModels > Bow / Sword / Fists` (los guantes: uno, se usa en los dos lados); si no están, se arman con piezas. Se escalan y orientan solos (el arco detecta para qué lado está la curva); para acomodar uno, atributos `Rotation` (Vector3, grados) y `Flip` (bool: espada al revés / curva del arco para el otro lado) en el modelo.

**Habilidades por arma.** Al subir de nivel salen cartas comunes (Fuerza, Cadencia, Vitalidad, Imán, Ojo de halcón, Golpe brutal, Encantamiento ígneo, Curación) y las del mazo de tu arma, que salen más seguido (`Config.Progression.WeaponDeckWeight`):
- 🏹 Arco: Flecha frontal, Abanico, Perforación, Rebote, Flecha trasera, Tiro cargado (cada 4º disparo, flecha gigante), Ojo del cazador (+25% a lejanos) y ⭐ Lluvia de flechas (cada 6 s).
- ⚔️ Espada: Hoja ancha, Hoja larga, Torbellino (cada 5º golpe, 360°), Ejecución (+60% a enemigos con poca vida), Sed de sangre (cura al matar) y ⭐ Juicio (espada gigante cada 8 s).
- 👊 Puños: Combo (+5% por golpe seguido, hasta +50%), Uppercut (cada 3er golpe lanza y aturde), Pies veloces y ⭐ Ráfaga de mil puños (cada 10 s, 2 s al triple de velocidad).
Las legendarias ⭐ solo aparecen con 2 habilidades del mazo de tu arma. Catálogo en `src/shared/Skills.lua`.

Con espada o puños, las habilidades de flechas que vengan de runas se convierten: flecha extra → +12% daño, par diagonal → +20° de arco, perforación y rebote → +8% daño cada una. Críticos, quemadura, daño y cadencia funcionan igual. Valores en `src/shared/Weapons.lua`. El Tocón verde y el Cactus ahora vuelan y mantienen distancia mientras disparan.

## Herramientas de prueba y balance

**Panel de stats** (botón **📊 Stats** del lobby; en partida, tecla **Tab** o el botón 📊 en celular). Muestra cada stat en columnas acumuladas: **Base → Equipo → Talentos → Runas** y, jugando, **Ahora** (con habilidades y objetos de la partida). En verde, lo que cambió respecto de la columna anterior: así se ve cuánto aporta cada sistema. Lo calcula el servidor (`StatsBreakdown`).

**Panel de prueba** (tecla **F2**). Solo aparece en Studio o para los UserId de `Config.Debug.Admins`; el servidor revisa el permiso en cada pedido, así que en el juego publicado nadie más puede usarlo. Botones: +5000 oro, +500 gemas, +50 piedras, +5 niveles de cuenta, desbloquear capítulos (queda guardado), resumen de partidas y, jugando: saltar oleada, matar enemigos, aparecer el jefe, subir de nivel, objeto al azar y curarse. Se apaga con `Config.Debug.Commands = false`.

**Registro de partidas** (`RunLog`, `Config.RunLog`). Al terminar cada partida anota una fila por jugador: capítulo, resultado, oleadas, duración, jugadores, bajas, daño, caídas, oro/gemas/piedras ganados, XP de cuenta y la build (puntos de talento, poder de equipo, runas, habilidades y objetos). Sale en la Salida como `[RunLog] ...` y se guarda en un DataStore aparte (`RunLog_v1`, una clave por día, sin tocar los perfiles). El botón **Resumen de partidas** del panel F2 (o `require(game.ServerScriptService.Server.RunLog).report(7)` en la barra de comandos del servidor) imprime promedios por capítulo de los últimos 7 días: % de victorias, oleadas, duración, oro, XP, bajas, DPS y caídas. Con esos números se ajustan costos y botín.

## Economía: misiones, tienda y balance

Todo se gana jugando (sin Robux; las cajas también se pueden pagar con Robux si se crean los Developer Products, ver abajo).

**Cuánto da una partida** (estimado con `Waves.buildQueue` y las tablas de botín, victoria completa de 10 oleadas):

| Capítulo | Bajas | Oro | Gemas | Piedras |
|---|---|---|---|---|
| 1 · Bosque Maldito | ~780 | ~1.600 | ~45 | ~19 |
| 2 · Ruinas Perdidas | ~750 | ~2.750 | ~46 | ~20 |
| 3 · Fortaleza Demoníaca | ~730 | ~4.500 | ~50 | ~22 |

Perder da el oro de las oleadas superadas y el botín juntado, sin el premio de victoria.

**Misiones** (`Shared/Missions.lua`, `MissionService`; botón **📜 Misiones** del lobby, con un aviso rojo cuando hay para cobrar). Cada jugador recibe 3 diarias (se renuevan a las 00:00 UTC, las 21:00 de Argentina) y 3 semanales (los lunes 00:00 UTC), sorteadas de una lista de 8 cada una. Siempre son las mismas en ese período aunque cambie de servidor. El progreso lo cuenta el servidor al terminar cada partida, ganada o perdida (abandonar no cuenta), y al abrir cajas. Se cobran a mano y, si el período termina sin cobrarlas, se pierden.
- Las 3 diarias dan en promedio **~770 oro y ~6 gemas**, más o menos media victoria del capítulo 1.
- Las 3 semanales dan **~6.000 oro, ~60 gemas** y a veces piedras, unas 2 victorias del capítulo 2.

**Tienda** (`Shared/ShopDefs.lua`, `ShopService`; botón **💰 Tienda**). Todo con monedas del juego:
- **4 ofertas de equipo por día**, distintas para cada jugador. Cada una se compra una vez. Precios:

  | Rareza | Precio |
  |---|---|
  | Común | 150 oro |
  | Poco común | 350 oro |
  | Rara | 800 oro |
  | Épica | 1.800 oro |
  | Legendaria | 90 gemas |

  Las míticas no se venden: se ganan jugando.
- **Cambios con límite diario:** 10 gemas por 400 oro (5 por día) y 300 oro por 5 piedras (5 por día).
- **Cofre de runas:** el mismo de Runas (60 gemas).

**Precios de referencia** (cuántas victorias del capítulo 2 hacen falta, contando las misiones):

| Qué | Costo | Victorias del capítulo 2 |
|---|---|---|
| Caja Common | 100 | — |
| Caja Rare | 500 | — |
| Caja Epic | 1.500 | ~½ |
| Caja Legendary | 5.000 | ~2 |
| Caja de armas | 10.000 | ~3–4 |
| Caja Secret | 15.000 | ~5 |

Un jugador activo (2 victorias por día más las misiones) junta unos **7.000 oro por día y ~50.000 por semana**. Con eso, en promedio:
- una mascota épica sale en ~1 semana;
- una legendaria, en 3 a 6 semanas.

**Cómo recalibrar con datos reales.** Hoy el registro tiene solo partidas de prueba, así que estos números son un modelo. Cuando haya jugadores:
1. Abrí el panel **F2 › Resumen de partidas**. Muestra, por capítulo: % de victorias, duración, oro (y oro por minuto), gemas, piedras, bajas y DPS de los últimos 7 días.
2. Compará el oro por partida real con la tabla de arriba. Si es bastante menor (por ejemplo, porque casi nadie gana), bajá los precios de `Crates.lua` y `ShopDefs.lua` en la misma proporción, o subí las metas y los premios de `Missions.lua`.
3. Las misiones deberían ser alrededor del 25% del oro diario de alguien que juega 2 partidas. Si con el oro por minuto se completan demasiado rápido, subí `Target`.

**Bono de daño de las mascotas** (`Config.Crates.PetDamageBonus`, revisado y sin cambios). Va de +2% (Common) a +20% (Secret) y multiplica el daño como el equipo. Para comparar:
- el equipo tiene un tope de +30% de daño;
- cada punto de talento de daño da +3% o +4%;
- la runa Furia da +2% por nivel.

Qué tan difícil es conseguir cada mascota (costo esperado por la mejor caja):

| Mascota | Rareza | Bono | Costo esperado |
|---|---|---|---|
| Gallina | Común | +2% | ~560 oro |
| Zorro | Poco común | +4% | ~3.300 oro |
| Lobo de Hielo | Rara | +6% | ~12.500 oro |
| Pantera Sombría | Épica | +9% | ~50.000 oro |
| Fénix | Legendaria | +12% | ~170.000 oro |
| Gato Cósmico | Secreta | +20% | ~30.000.000 oro |

Hasta Legendaria es una meta razonable jugando. El +20% de la Secreta es prácticamente inalcanzable con oro, así que solo pesa si la caja Secret se vende por Robux: ahí sería una ventaja pagada de +20% de daño. Si eso preocupa, hay dos opciones: no ponerle `ProductId` a la caja Secret, o bajar Secret a +14%.

## Cajas (crates)

Al este del lobby hay una puerta a la **plaza volcánica**: una plataforma por caja. Acercate y apretá **E** ("Ver cajas") para abrir el menú; **OPEN** compra y abre. Para probar en Studio te da 25.000 monedas una vez (`Config.Crates.TestGold`); también está el +5000 oro del panel F2.

**Cambiar precios y probabilidades:** `src/shared/Crates.lua`. Cada caja tiene `Price` y una lista `Prizes` con `{ Prize = "Id", Chance = % }`. Las Chance pueden no sumar 100 (se reparten en proporción), pero la prueba `test_crates` avisa si no suman 100 para que lo que ves en DROP RATES sea exacto. Una caja nueva suma su plataforma sola.

**Cambiar o agregar premios:** `src/shared/CrateItems.lua`. Cada premio tiene `Id` (no lo cambies una vez publicado: el inventario guardado lo usa), `Name`, `Rarity` (Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret), `Kind` (Unit, Pet, Character, o Weapon para armas especiales) y `Look` (colores y accesorios del modelo de bloques). Después ponelo en la tabla de alguna caja.

**Trajes detallados:** `src/shared/CrateLooks.lua`. Un premio de personaje con entrada ahí se ve con ese traje en tu avatar, en el Index y en la animación (ejemplo: `FireDemon`). Cada pieza dice a qué parte del cuerpo va (`Torso`, `Head`, `LeftArm`...), tamaño, color, material y posición, con medidas de cuerpo clásico (sirven los morphs R6 adaptando los números).

**Tus propios modelos:** creá en Studio `ReplicatedStorage > CrateAssets > Prizes` y meté un Model con el `Id` exacto del premio, mirando hacia -Z y con el pivote en los pies. Se usa en el índice y en la animación; se le borran los scripts. Lo mismo para los cofres en `CrateAssets > Crates` con el Id de la caja.

**Sistema:** `Config.Crates`: moneda (`Currency`, el oro), nombre de la columna de leaderstats, límite entre aperturas, distancia a la plataforma, monedas de prueba, tamaño de la plaza, luz volcánica y tiempos de la animación (temblor, giro de cámara, vueltas y velocidad de la ruleta). Sonidos en `Shared/Sounds.lua` (`Crate*`).

**Antes de publicar:** dejá `TestGoldOnlyInStudio = true` (o `TestGold = 0`).

**Seraphiel y las armas celestiales:** el skin Mythic Seraphiel es un traje de cuerpo completo (`CrateLooks.Seraphiel`, mallas en `CrateAssets > Looks > Seraphiel`) y desbloquea la Espada Celestial (`Weapons.CelestialSword`, `Prize = "Seraphiel"`). El Arco Celestial se obtiene por separado en el Cofre de Armas (`Prize = "CelestialBow"`), sin necesitar el skin. Para probar: panel F2 → "Darme y equipar Seraphiel", después elegir el arma. El arco tiene modelo procedural en primera y tercera persona, flechas de energía, estelas eléctricas e impactos de rayo; conserva las habilidades del arco base. Sus efectos se reducen en calidad baja y no requieren importar texturas. Si hay que volver a generar el modelo de la espada: `Seraphiel_Blender.py` (Blender 5.2) → importar `Seraphiel_Roblox_Optimized.fbx` → repetir el armado de `Looks > Seraphiel` y `WeaponModels > CelestialSword` (está explicado en el CHANGELOG del 22/10).

**Efectos de las skins:** `src/shared/SkinFx.lua`. Cada skin tiene su paleta (`Colors`: pisadas, aura y estela de `LavaSkinFx`) y, si querés, flechas propias (`Arrow`: vara, punta, estilo de texturas de `FxStyles`, llamas, brasas, luz, estela e impacto). Hoy el Demonio Ígneo tiene flechas de fuego; el Mago Cósmico y el Necromante solo la paleta. Es todo visual: lo dibuja cada cliente (`Client/SkinArrowFx`) y en calidad baja se simplifica. Para probar: panel F2 → "Darme y equipar Demonio Ígneo" y jugá una partida con arco.

**Cofres y huevos:** en `src/shared/Crates.lua` cada entrada tiene `Type`: `"Crate"` (cofre de skins: personajes y unidades) o `"Egg"` (huevo de mascotas). Cada tipo tiene su fila en la plaza, su pestaña en el menú (Skin Crates / Pet Eggs) y su animación. Un cofre no puede dar mascotas ni un huevo skins (la prueba lo revisa).

**Cómo se paga cada caja:** `PayWith` en `src/shared/Crates.lua`. Hoy Common (100), Rare (500) y Epic (25.000) se abren con monedas del juego; Legendary y Secret solo con Robux. Para cambiar una caja de forma de pago, cambiá `PayWith` ("Coins" o "Robux").

**Vender cajas por Robux:**
1. Publicá el juego y andá al [Creator Dashboard](https://create.roblox.com/dashboard/creations) › tu experiencia › **Monetization › Developer Products › Create a Developer Product**. Creá uno por caja (por ejemplo "Rare Crate") con su precio en Robux.
2. Copiá el **Product ID** de cada uno y pegalo en `ProductId` de esa caja en `src/shared/Crates.lua`. El precio en Robux se cambia en el Dashboard, no en el código (el botón lo lee solo).
3. Probá en Studio: la compra es de prueba (no cobra) y tiene que estar activado *Game Settings › Security › Enable Studio Access to API Services* para que se guarde el perfil.
Roblox exige mostrar las probabilidades antes de comprar (ya están en DROP RATES: no las saques) y no vender cajas pagas al azar en algunos países: el juego lo consulta con `PolicyService` y ahí el botón no aparece.

**Equipar:** en la pestaña **Index**, EQUIP sobre un premio que tengas. Un espacio de **mascota** (te sigue y da daño extra según su rareza, `Config.Crates.PetDamageBonus`) y uno de **personaje** (unidades y personajes: cambian tu avatar por el de bloques del premio, solo aspecto). Se equipa en el lobby y queda guardado.

## Pruebas automáticas

En `tests/` (fuera de lo que sincroniza Rojo). Corren los módulos reales del servidor sobre una imitación mínima de Roblox:

| Prueba | Qué cubre |
| --- | --- |
| `test_match.luau` | Ciclo de partida: solo, dos jugadores, cancelar listo, desconexión en la cuenta, victoria y vuelta, derrota y vuelta, segunda partida, partidas duplicadas, líder, equipo lleno, permisos y peticiones inválidas; recompensas entregadas y guardadas, volver a entrar con todo, no poder ponerse listo mientras carga el perfil |
| `test_playerlife.luau` | Derribo, rescate, eliminación, descanso, lobby a salvo, entradas y salidas |
| `test_catalog.luau` | Catálogo de enemigos y capítulos, escalado coop de oleadas, variedad |
| `test_dopamine.luau` | Arranque rápido de niveles (4, 9, 16, 25 y después la fórmula), marca de jefe en las muertes, carta dorada (solo con lugar para 2 niveles, da 2, sin chance no sale) y lista de sinergias (Ids reales, mismo mazo, sin repetidos) |
| `test_grab.luau` | Agarre: anclado sin atacar ni dash, daño de a poco, rescate por daño o muerte del agarrador (quién te salvó), forcejeo con tope de frecuencia, cuándo no agarra, derribo y tope de tiempo, la IA salta y agarra, el Atrapador en todos los capítulos |
| `test_manual_fire.luau` | Ataque manual: sin apretar no ataca; apunta a la mira y no al enemigo; cadencia al mantener; click en cola; espada al aire; validación y límite de mensajes |
| `test_aim.luau` | Puntería: en primera persona solo apunta adelante; en cenital, a todo alrededor; dispara caminando |
| `test_ai.luau` | 60 s de cada enemigo y jefe: sin errores, todos atacan, los jefes cambian de fase |
| `test_profiles.luau` | Perfil: nuevo, guardar y volver, monedas, reintentos, DataStore caído, Studio sin acceso, bloqueo de sesión (esperar, tomar, abandonado, perdido, mismo servidor), migraciones, datos rotos, versión nueva, irse mientras carga, guardado automático y cierre del servidor |
| `test_rewards.luau` | Cálculo de recompensas: derrota, jefes, primera victoria, valores fuera de rango, los tres capítulos |
| `test_runes.luau` | Runas: niveles por duplicados, piedras por repetidas, espacios activos según capítulos ganados, cofre con gemas, bonus, guardado y datos rotos |
| `test_loot.luau` | Botín por enemigo y jefe, multiplicador del capítulo, variación; números flotantes agrupados, quemadura, daño recibido, XP y frecuencia de envío |
| `test_orbs.luau` | Orbes de XP (imán, aspiradora, tope, envío a los clientes) y cofres (cuándo aparecen, tope, abrir, abrir al final) |
| `test_selection_pause.luau` | Pausa global, inmovilidad, inmunidad, proyectiles, quemaduras, espera cooperativa y limpieza |
| `test_equipment.luau` | Equipo inicial, validaciones, costos, fusión, reciclaje (pieza y lote), topes, persistencia y reparación de perfiles |
| `test_enemy_reach.luau` | Distancia de aparición, aparición desde varios lados y por la espalda, acercamiento en curva (rodear), atracción desde lejos, reubicación de quietos y lejanos, ojos, borrado de scripts de los modelos, aviso de enterrados y vuelta adentro del mapa |
| `test_weapons.luau` | Armas: elegir (validaciones), perfil, golpe en arco (adelante sí, atrás y lejos no), bonos de habilidades, cadencia, sin flechas con espada, enemigos voladores |
| `test_weapon_skills.luau` | Mazos por arma, legendarias con requisito, flecha trasera, tiro cargado, ojo del cazador, hoja larga, ejecución, sed de sangre, torbellino, combo, uppercut (aturde) y los tres poderes legendarios |
| `test_tools.luau` | Panel de stats (columnas, sin tocar las stats reales, frecuencia), registro de partidas (fila, promedios, tope, una escritura, Studio sin DataStore) y comandos de prueba (permisos Studio/admins, pedidos ajenos ignorados, validación y comandos de partida) |
| `test_talents.luau` | Árbol: todo alcanzable, costos crecientes, conexión, puntos por nivel, oro y gemas, máximo, listo/partida, frecuencia, reinicio, stats, perfil v4, XP de cuenta, Codicia, Ventaja y cambio de cartas |
| `test_items_dash.luau` | Acumulación, aura, rayos, explosiones, sinergias, modo opcional sin pausa, dash, invocaciones y limpieza |
| `test_map.luau` | Relieve: misma semilla mismo mapa, centro plano, montañas en el borde, mesetas con rampa caminable, altura del piso, decoración, mapa hecho a mano, enemigos apoyados y a buena distancia |
| `test_rooms.luau` | Puerta entre oleadas: hay que entrar todos, límite de tiempo, cambio de sala, entrada, salas hechas a mano, más enemigos por oleada, decoración en los bordes |
| `test_crates.luau` | Cajas: precios y rarezas, tablas que suman 100%, tirada ponderada, compra (cobra, guarda, repetidos), sin monedas, pedidos inválidos, límite de frecuencia, lejos o en partida, colección, Robux (PolicyService, compra, recibo una vez, sin guardar no confirma, repetidos, tope), equipar (espacios, validación, partida, frecuencia), bono de mascota, perfil v8 y plaza con sus prompts |
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
