# Cambios

## 2026-10-21 · Huevos de mascotas

- **Cofres = solo skins:** los 5 cofres (Common → Secret) ya no dan mascotas; sus probabilidades se repartieron entre personajes y unidades (cada uno suma 100%).
- **4 huevos de mascotas** (`Type = "Egg"` en `Shared/Crates.lua`): Common Egg (150), Rare Egg (750) y Epic Egg (20.000) con monedas; Mythic Egg solo con Robux. Fila propia de plataformas contra el muro sur de la plaza (más ancha: 100 studs), con el huevo flotando, antorchas, cartel y prompt "Ver huevos".
- **9 mascotas nuevas:** Perrito, Gatito, Conejo, Cerdito, Loro, Slime de Lava, Unicornio, Dragoncito y Dragón de Tormenta (accesorios nuevos: orejas largas, hocico, cuerno, cuernos).
- **Huevo ornamentado** (`CrateModels.egg`): cáscara, bandas de neón, zigzag dorado, gemas y corona, del color de cada huevo.
- **Animación de huevo** (`EggCinematic`, nueva, a pantalla completa): el huevo se sacude cada vez más con destellos; si viene Epic o mejor, "!! RARE SIGNAL DETECTED !!" (desde Legendary, rayos y arcoíris); se rompe con flash y pedazos; rendija de luz → columna con rayos en estrella y la silueta de la mascota; reveal con fondo de su rareza, anillos y la mascota a color; bono de daño y "Continue".
- **Menú:** pestañas Skin Crates / Pet Eggs / Index; el prompt de un huevo abre la pestaña de huevos. `CrateItems.upper` respeta acentos en mayúsculas (DRAGÓN).
- Pruebas: `test_crates` (24): cofres solo skins, huevos solo mascotas, todo premio sale de alguna caja, abrir un huevo (26/26 archivos OK). Probado en Studio: plaza, menú, huevo real con monedas, reveal y vuelta, sin errores.

## 2026-10-21 · Trajes detallados: Demonio Ígneo

- **`Shared/CrateLooks.lua`** (nuevo): trajes de premios de personaje como datos (piezas por segmento del cuerpo, color y material de piel, brasas). Se aplican al avatar R15 al equiparlo (cada pieza se suelda al segmento que le toca, así acompaña la animación) y al modelo de bloques del Index y de la animación de apertura.
- **Demonio Ígneo:** primer traje, del diseño de Codex (morph R6) pasado a datos y adaptado a R15: coraza con grietas de lava y núcleo que brilla, placa central, hombreras, brazales con borde de lava, grebas, cuernos con punta de lava, alas de cristal, ojos y máscara, y brasas. La cara de Roblox se oculta; al desequipar vuelve la piel normal.
- Pruebas: `test_crates` valida los trajes (22). Probado en Studio: avatar, vista previa del Index y sin errores.

## 2026-10-21 · Cajas de monedas y cajas de Robux

- Cada caja se paga de una sola forma (`PayWith` en `Shared/Crates.lua`): **Common (100), Rare (500) y Epic (25.000)** con monedas del juego; **Legendary y Secret solo con Robux** (sin precio en monedas).
- El servidor rechaza abrir una caja de Robux con monedas y vender por Robux una de monedas. Sin `ProductId`, la caja de Robux se ve con "Pronto" (tarjeta y cartel de la plaza) y no se puede comprar.
- El precio en Robux se lee del Developer Product (`GetProductInfo`) en la tarjeta y en el cartel de la plaza.
- `Config.Crates.TestGold` sube a 30.000 (alcanza para probar la Epic en Studio).
- Pruebas: `test_crates` (21) actualizado; probado en Studio.

## 2026-10-20 · Cajas con Robux y premios equipables

- **Robux por caja:** cada caja puede tener un Developer Product (`ProductId` en `Shared/Crates.lua`; 0 = sin Robux). Botón verde "R$" con el precio real (`GetProductInfo`) debajo de OPEN. El servidor valida (lobby, cercanía, límite, perfil guardable) y muestra la compra; el premio se entrega con el recibo.
- **Recibos seguros** (`Receipts`, nuevo): único dueño de `ProcessReceipt`. Cada entrega anota el `PurchaseId` en el perfil y recién confirma cuando quedó guardado (`Profiles.saveNow`); un recibo repetido no entrega dos veces y uno que no se pudo guardar se reintenta sin duplicar. Se recuerdan los últimos `MaxSavedReceipts`. El cliente recibe `Remotes.CrateOpened` y muestra la animación (si estás en partida, al volver).
- **Reglas de Roblox:** probabilidades a la vista antes de comprar (DROP RATES) y `PolicyService.ArePaidRandomItemsRestricted`: donde no se permite, no aparece el botón y el servidor no vende (si no se puede consultar, tampoco).
- **Equipar** (`CrateEquip`, nuevo): un espacio de mascota y uno de personaje (unidades y personajes). Botón EQUIP / EQUIPPED en Index y línea con lo equipado. Solo lo que tenés y en el lobby, con límite de frecuencia; queda en el perfil (versión 8).
- **Mascota** (`PetFollow`, cliente nuevo): te sigue flotando a tu lado (todos ven las de todos, sin costo de red) y da daño extra según rareza (`Config.Crates.PetDamageBonus`: Common +2% … Secret +20%), sumado al arrancar la partida y visible en el panel de stats (columna "Mascota").
- **Personaje:** tu avatar pasa a ser de bloques con los colores del premio (HumanoidDescription sin ropa ni accesorios de Roblox) más sus accesorios (corona, cuernos, alas, aureola...) y ojos. Solo aspecto. Al sacarlo vuelve tu avatar.
- Pruebas: `test_crates` suma Robux, recibos (una vez, sin guardar, repetidos, tope), equipar, bono de mascota y perfil v8 (21); `test_tools` con la columna Mascota (26/26 archivos OK). Probado en Studio: equipar, mascota que sigue, aspecto del avatar, persistencia y desequipar, sin errores. La compra con Robux no se pudo probar en Studio porque todavía no hay productos creados.

## 2026-10-20 · Cajas (crates) con apertura cinematográfica

- **Plaza volcánica** (`CratePlaza`, `Shared/CratePlazaLayout`): al este del lobby, con una puerta en su muro (`Config.Crates.Plaza`). Piso de roca con grietas de lava, charcos, muros de basalto, arco "CRATES" y una plataforma hexagonal por caja con borde de neón, el cofre flotando, antorchas, cartel (nombre y precio) y un ProximityPrompt que abre el menú.
- **Luz volcánica** (`Atmosphere`, `Config.Crates.Lighting`): al entrar a la plaza (o durante una apertura) cielo de atardecer rojizo, niebla cálida, bloom y tinte. El Sky y la Atmosphere del place se apartan solo en tu pantalla y vuelven al salir.
- **5 cajas** (`Shared/Crates.lua`): Common 100, Rare 500, Epic 1.500, Legendary 5.000 y Secret 15.000 monedas, cada una con su tabla de premios y probabilidades. **19 premios** (`Shared/CrateItems.lua`) en 7 rarezas (Common → Secret): unidades, mascotas y personajes de bloques (`Shared/CrateModels.lua`), reemplazables por modelos propios en `ReplicatedStorage/CrateAssets/Prizes`.
- **Servidor** (`CrateService`, `Remotes.CrateRequest`, RemoteFunction): valida caja, perfil cargado, estar en el lobby, límite de frecuencia (`OpenCooldown`), cercanía a una plataforma (`StationRange`) y monedas; recién ahí cobra, tira con `Random` del servidor y guarda. Los premios van en el perfil (`Crates.Owned`, versión 7). Leaderstats "Monedas" (el oro del perfil) y monedas de prueba una vez por perfil (`TestGold`, solo Studio).
- **Menú CRATES** (`CrateUI`): pestañas Shop Crates / Index, tarjetas con el cofre girando, brillo de su color, precio y OPEN; DROP RATES con barra proporcional y porcentaje; índice con siluetas de lo que falta. Se escala a la pantalla.
- **Animación** (`CrateCinematic`): negro y título con línea brillante, arena propia (lava, pedestal, arcos rojos, antorchas, brasas), la caja cae, tiembla, brilla y explota; los premios en círculo con anillos de su rareza y la cámara girando; ruleta que frena en el ganador; haz de luz y partículas (más fuertes con sacudón desde Legendary); nombre, rareza y "Continue". Al terminar se desconecta y borra todo.
- `CameraController` no toca la cámara con el atributo `Cinematic`. `Lobby` deja la puerta en el muro este.
- Pruebas: `test_crates.luau` nueva (13); `mocks` con NumberSequence/ColorSequence/NumberRange; `test_match` y `test_equipment` apagan las monedas de prueba (26/26 archivos OK). Probado en Studio: plaza, menú, compra, animación completa, limpieza, sin errores en la consola.

## 2026-10-20 · Gárgolas que vuelan y esqueletos de tu tamaño

- **Esqueletos del tamaño de un personaje:** `HordeSkeleton`, `SkeletonArcher` y `RedArcher` pasan a `Height = 5.5` (como el R15 del jugador; antes 3.4–3.6). El modelo se escala a esa altura.
- **Gárgolas (murciélagos) en el aire:** `GreenBat`/`RedBat` vuelan a `Float = 4` (a la altura de los ojos; antes 2.5) y suben y bajan con un vaivén (`Config.Enemy.FlyBob` 0.6 studs, `FlyBobSpeed` 2.2), cada uno a su ritmo (`bobPhase`). Los golpes siguen siendo planos: la altura no cambia a quién le pegás.
- **Aleteo** (`EnemyAnimator`, cliente nuevo): las piezas del modelo dentro de un grupo con "wing" en el nombre aletean desde la unión con el cuerpo (`WingFlapAngle` 35°, `WingFlapSpeed` 14). Solo en pantalla, sin costo de red; lejos de la cámara (`AnimateDistance` 150) quedan quietas.
- Modelos generados con IA en `ServerStorage/EnemyModels` (en el place, no en el repo): Grabber, HordeSkeleton, SkeletonArcher, RedArcher, GreenSlime, RedSlime, KingSlime, GreenBat, RedBat.
- Pruebas nuevas en `test_enemy_reach.luau` (25/25 archivos OK).

## 2026-10-20 · Agarre y rescate

- **Atrapador** (`EnemyTypes.Grabber`): enemigo nuevo violeta, en todos los capítulos desde la oleada 3 con peso bajo (sale de a uno cada tanto). Ataque `Grab`: aviso y salto; si te alcanza, te agarra.
- **Agarrado** (`Grab.lua`, `Config.Grab`): raíz anclada, sin atacar ni dash, `Dps` cada `TickTime`. Te suelta si un compañero le saca `ReleaseDamageFraction` (25%) o lo mata, si machacás `StrugglePresses` (16) veces, si te derriban o a los `MaxHold` (10) s. Después queda aturdido, sale despedido y no vuelve a agarrar por `RegrabCooldown`.
- El salto revisa el contacto en todo el tramo del frame: con lag no atraviesa al jugador.
- **Cliente** (`GrabUI`): pantalla roja, "¡TE AGARRARON!", barra de forcejeo y botón táctil; "¡AYUDA!" sobre el compañero agarrado; "¡X te salvó!" / "¡Salvaste a Y!" con arpegio.
- Pruebas: `test_grab.luau` nueva; `test_catalog` acepta el ataque `Grab` (24/24 archivos OK).

## 2026-10-20 · Hordas desde todos lados

- Cada aparición se reparte en `Config.Frenzy.SpawnSides` (3) grupos desde direcciones distintas alrededor de un jugador, rotando en cada aparición; con `BehindSpawnChance` (50%) uno sale por su espalda. `SpawnGroup` pasa de 5 a 6 (2 por lado).
- Rodear en vez de hacer fila: cada enemigo que persigue tiene su propio desvío (hasta `Config.Enemy.FlankAngle` = 50°) y se acerca en curva; se endereza entre `FlankFar` (35) y `FlankNear` (12) studs. Los jefes van directo.
- Pruebas nuevas en `test_enemy_reach.luau` (23/23 archivos OK).

## 2026-10-20 · Más dopamina (segunda tanda)

- **Orbes en escalera:** cobrar XP seguido sube de nota (pentatónica); se reinicia tras una pausa (`Config.Effects.OrbLadderNotes`, `OrbLadderWindow`).
- **Números con racha:** tus números de daño crecen con el combo (hasta +60% en x50, `Config.CombatText.ComboGrow`/`ComboGrowAt`); los críticos salen en arcoíris.
- **Carta dorada sorpresa** (`Config.Progression.GoldenCardChance` = 5%): el servidor marca una carta (solo habilidades con lugar para 2 niveles); si la elegís, se aplica 2 veces. Viaja como 6º dato de `SkillOffer`. Borde de oro, "✦ ×2" y arpegio al darse vuelta.
- **Sinergias:** `Shared/Synergies.lua` con 14 pares; al completar uno, cartel "¡SINERGIA!" en arcoíris con los dos nombres y arpegio (una vez por partida). Solo aviso, sin bono.
- Pruebas nuevas en `test_dopamine.luau` (23/23 archivos OK).

## 2026-10-20 · Más dopamina

- **Racha con notas:** cada muerte seguida del combo suena una nota más aguda (pentatónica, `Config.Effects.StreakNotes`); hitos con cartel y arpegio desde x10.
- **Racha en arcoíris:** el contador, la palabra COMBO, la barra y los carteles de hitos van en un arcoíris que corre de costado y se acelera con la racha (antes cambiaban de blanco a amarillo, naranja y rosa).
- **Pausa de impacto** en tus críticos, dorados y jefes: el arma se congela, la cámara se acerca y la pantalla destella (`Config.Effects.HitStop`, `HitStopGap`, `HitStopFov`). Las muertes de jefes viajan marcadas en `CombatText` (`b = true`).
- **Arranque rápido:** los primeros niveles piden 4, 9, 16 y 25 de XP (`Config.Progression.EarlyLevelMult`); después, la fórmula de siempre.
- **Legendarias con suspenso:** la carta tarda 1,6 s en revelarse con redoble, y aparece con destello dorado y cartel. No se puede elegir hasta que se revelan todas.
- **Resultados:** monedas que cuentan hacia arriba, nuevo récord o "te faltó N para tu récord / para ganar", mejor racha y barra de cuenta "te faltan X XP para el próximo punto de talento". El servidor manda `bestWaveBefore`, `newRecord` y `account` en el resumen.
- **Botón ¡OTRA!** (`LobbyRequest "PlayAgain"`, validado igual que volver): al llegar al lobby quedás listo con el mismo capítulo; si todos los listos vienen de OTRA, la cuenta es de `Config.Match.AgainCountdownTime` (3 s).
- Pruebas: `test_dopamine.luau` nueva y caso de OTRA en `test_match.luau` (23/23 archivos OK).

## 2026-10-13 · Ataque manual

- Ya no se ataca solo: click izquierdo (R2 / botón ATACAR en el celular) hacia donde apunta la mira, con las tres armas. Mantener apretado sigue atacando a la cadencia del arma; un click en la recarga queda en cola.
- El cliente solo manda "apretado + dirección" (`Remotes.AttackRequest`); el servidor valida tipos, números, partida, vida y frecuencia, y pone el origen, la cadencia y el daño.
- `Config.Player.FireMode = "Auto"` vuelve al ataque automático. Prueba nueva `test_manual_fire.luau`; las pruebas del ataque automático lo fijan en "Auto" (22/22 archivos OK).

## 2026-10-13 · Habilidades por arma (primera tanda)

- Mazos por arma: comunes + las del arma (más frecuentes). "Flechas de fuego" pasa a ser común como "Encantamiento ígneo".
- Arco: Flecha trasera, Tiro cargado, Ojo del cazador y ⭐ Lluvia de flechas. Espada: Hoja ancha, Hoja larga, Torbellino, Ejecución, Sed de sangre y ⭐ Juicio. Puños: Combo, Uppercut (con aturdimiento), Pies veloces y ⭐ Ráfaga de mil puños.
- Legendarias con requisito de 2 habilidades del mazo. Visuales nuevos: flecha gigante, lluvia, espada del Juicio y anillo de la ráfaga.
- Prueba nueva `test_weapon_skills.luau` (21/21 archivos OK).
- Arma en primera persona estilo shooter: solo el ítem, sin brazos. El arco se ve de frente (a la izquierda, inclinado) con la flecha cargada que se tensa, sale y se recarga; la espada abajo a la derecha; un guante a cada lado. El arco detecta solo para qué lado está la curva (`Flip` la invierte).
- Arma en primera persona con manos de Roblox en bloque (color de tus brazos) que sostienen el ítem; interruptor `Config.Effects.FirstPersonWeapon`. El arco se ve solo, cerca del cuerpo y apuntando al frente; la flecha cargada es una flecha de verdad (astil redondo, punta de metal, plumas doradas y culatín) que se desliza hacia atrás al tensar. Los modelos de `WeaponModels` pueden ser una sola MeshPart.

## 2026-10-12 · Armas y enemigos voladores

- Arma del jugador a elegir en el lobby: arco, espada (tajo en arco) o puños (rápidos). Golpes cuerpo a cuerpo validados en el servidor y dibujados en el cliente; habilidades de flechas convertidas para cuerpo a cuerpo.
- Perfil v6 (`Weapon`), arco por defecto.
- Tocón verde y Cactus vuelan y mantienen distancia.
- Modelos de enemigos: carpetas con varios modelos (uno fijo por tipo), teñidos con el color del enemigo; alto mínimo 5.
- Prueba nueva `test_weapons.luau` (20/20 archivos OK).

## 2026-10-12 · Vuelta atrás del estilo dark fantasy

- Se sacaron los biomas dark fantasy (luz, cielo, niebla, terreno, fondo, decoración y partículas): el mapa vuelve a verse como antes. Se mantienen el pasto bajo, los indicadores de enemigos y los bordes del mapa.

## 2026-10-11 · Biomas dark fantasy

- `Biomes.lua` + `BiomeBuilder.lua`: un bioma por capítulo con noche estrellada, luna grande, horizonte magenta, niebla índigo y paleta propia.
- Borde con picos dentados, parches de lajas en el piso y paisaje de fondo afuera de las paredes: cañón con río (o lava), agujas de roca, mar de niebla y catedrales góticas con ventanas encendidas.
- Decoración nueva: peñascos, agujas, lajas, arcos rotos, estatuas encapuchadas y velas.
- Pruebas: fondo solo afuera del área jugable, borde dentado sin tocar el interior y decoración mezclada.

## 2026-10-11 · Dark fantasy, flecha a los últimos y pasto bajo

- Estilo `DarkFantasy` (por defecto): atardecer oscuro, niebla densa por capítulo, colores apagados, rayos de luz, terreno oscuro, decoración tétrica y partículas ambientales. `Day` conserva el estilo anterior.
- Pasto del terreno más bajo (`GrassLength` 0.35).
- Flecha arriba de la pantalla hacia el enemigo más cercano cuando quedan pocos, con cantidad y distancia.
- Arreglo: los indicadores de enemigos esperaban `GameState` en el lugar equivocado y no aparecían.

## 2026-10-11 · Indicadores de enemigos y bordes del mapa

- Rombo brillante sobre cada enemigo, visible a través de todo, con color por tipo; late cuando quedan 10 o menos.
- Paredes del borde más altas y gruesas, cruzadas en las esquinas, y techo invisible.
- Red de seguridad del servidor: quien queda afuera del mapa o cae debajo del piso vuelve adentro, sobre el terreno.

## 2026-10-11 · Enemigos que vienen a vos y modelos

- Aparecen más cerca (26–50 studs). Desde lejos, todos los que caminan van directo al jugador más cercano, a velocidad mínima 14.
- Los que quedan muy lejos (75 studs, o 45 los quietos) por 3 s reaparecen cerca del equipo.
- `EnemyVisuals`: modelos por tipo en `ServerStorage > EnemyModels`, escalados, apoyados y soldados a la caja de colisión; scripts borrados; animación Walk/Idle opcional; brillo para parpadeo y quemadura. Sin modelo: figura con ojos.
- Prueba nueva `test_enemy_reach.luau` (19/19 archivos OK).

## 2026-10-11 · Herramientas de prueba y balance

- **Panel de stats** (lobby: botón Stats; partida: Tab / 📊): base → equipo → talentos → runas → ahora, calculado por el servidor.
- **Panel de prueba F2** (solo Studio o admins de `Config.Debug.Admins`, validado en el servidor): monedas, niveles de cuenta, capítulos, saltar oleada, matar enemigos, jefe, subir de nivel, objeto, curar y resumen de partidas.
- **Registro de partidas** (`RunLog`): una fila por jugador al terminar, en la Salida y en un DataStore aparte por día; resumen por capítulo para balancear.
- Revisión de migraciones del perfil después del merge de runas: cadena v1 → v5 sin huecos.
- Prueba nueva `test_tools.luau` (18/18 archivos OK).

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
