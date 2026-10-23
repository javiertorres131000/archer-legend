# Cambios

## 2026-10-23 · Guanteletes Volcánicos (primera arma de puño especial)

- **Modelo propio** hecho en Blender por código (`assets/weapons/VolcanicGauntlets/`: script, FBX y renders). Son 3 piezas, una por material: armadura (Armor), roca (Rock) y magma (Glow).
- **Arma** (`Shared/Weapons`, Base `Fists`):
  - Cada golpe quema (30% por segundo, 3 s).
  - Cada 6º golpe hace erupcionar el piso alrededor tuyo (radio 11, ×2) y quema todo (Finisher `Eruption` con `Every`).
  - Efectos con el estilo Inferno.
- **Cofre de Armas:** el premio nuevo en `CrateItems` y las probabilidades repartidas entre las 6 armas.
- **Tercera persona:** `Client/GauntletModels` pone el guantelete en las dos manos. `HeldWeapon` ya no intenta poner los guanteletes como un arma de una mano. En primera persona los dibuja `WeaponFx` con el modelo de `WeaponModels`.
- **Arreglo:** en primera persona `WeaponFx` escondía cualquier guante (solo mostraba los brazos). Ahora los guanteletes con modelo propio se ven. En tercera persona se ven también en el lobby.
- **Pruebas:** `test_crates` abre también la sexta arma.

## 2026-10-23 · Las armas especiales hacen lo que muestran

Antes los efectos de las armas especiales eran solo visuales. Ahora tienen poderes reales: campo `Power` en `Shared/Weapons`, aplicado en `Server/SkillEffects`.

| Arma | Cada golpe | Remate o especial |
|---|---|---|
| Hoja Infernal | Quema: 35% del golpe por segundo, 3 s | 3er tajo: explosión de fuego (radio 10, ×1,6) que quema a todos |
| Katana Carmesí | Sangrado: 25% por segundo, 3 s | 3er tajo: esfera roja gigante (radio 13, ×2,2) |
| Espada Celestial | 35% de rayo que salta a 3 enemigos (50% del golpe) | 3er tajo: rayos del cielo sobre 4 enemigos (×1,8) |
| Arco Celestial | El rayo salta siempre a 2 enemigos (35% del golpe) | Cada 5 impactos: rayo del cielo con explosión (radio 7, ×1,5) |
| Arco del Vacío | Grieta violeta: 2,5 s, daña 30% por segundo y atrae enemigos (máx. 3 grietas) | Se mantiene la flecha perforante cada 4 disparos |
| Katana de Escarcha | Frena 40% durante 2 s | 3er tajo: estallido de hielo (radio 9, ×1,4) |

- Los efectos visibles usan los avisos existentes de `SkillFx` (`Chain` y `Blast`).
- Las descripciones de las armas explican qué hace cada una.

## 2026-10-23 · Capítulo 3: Glaciar Eterno (todo de hielo)

- **Orden de los capítulos:** el Glaciar pasa a ser el 3 (se desbloquea con Ruinas Perdidas) y la Fortaleza Demoníaca el 4 (con el Glaciar). Los Id no cambian, así que los perfiles guardados siguen valiendo.
- **Dificultad y recompensas:**
  - Glaciar: vida ×2,1, daño ×1,4, más presupuesto y spawns más rápidos.
  - Fortaleza: vida ×2,5 y daño ×1,5.
  - Las recompensas se intercambiaron según el nuevo orden.
- **Enemigos solo de hielo:**
  - Variantes de los roles comunes: `FrostSkeleton`, `FrostKnight` (con ráfaga radial), `FrostCaptain`, `FrostGrabber` e `IceArcher`.
  - Nuevos: `IceWraith` (flota, se teletransporta y tira carámbanos) e `IceSlimeling` (el slime de hielo se parte en trozos helados).
  - Yeti: 3400 de vida.
  - Reina de Hielo: 12000 de vida y una tercera fase con disparos que rebotan, tormenta de carámbanos e invocación de espectros.
- **Frío** (`Server/Chill`, `Config.Chill`):
  - Cada golpe que recibís suma un punto de frío, y cada punto te frena un 9%.
  - Con 5 puntos quedás congelado 1,3 s y después tenés 3,5 s de inmunidad.
  - El frío se va solo, y mucho más rápido junto a una fogata.
- **Eventos del mapa** (`Server/GlacierEvents`, `Config.MapEvents.glacier`):
  - Carámbanos que caen sobre los jugadores (el primero justo donde estás parado) y suman 2 de frío.
  - Ventisca cada 24 a 34 s: aviso, 8 s de viento que empuja y frío continuo si no estás en una fogata.
  - 5 fogatas con un anillo cálido.
- **Resbalar** (`Client/IceWorld`, `Config.IceGrip`): sobre los lagos congelados (material Ice) acelerás, frenás y doblás despacio. Sobre la nieve caminás un 12% más lento.
- **Mapa:**
  - Lagos de hielo generados con ruido y colores de nieve, hielo y glaciar.
  - Decoración nueva: racimos de cristales (algunos con luz), rocas congeladas, estalagmitas, aventureros congelados en bloques de hielo, pilares de hielo y pinos más grandes.
- **VFX** (`Client/IceWorld`):
  - Aire y cielo: polvo de diamante, nieve barrida por el viento y aurora boreal animada.
  - Luz y pantalla: corrección de color fría, bloom, rayos de sol y desenfoque lejano.
  - Ventisca: nieve horizontal, ráfagas y pantalla blanca.
  - Frío: escarcha en los bordes de la pantalla y medidor de frío.
  - Personajes: bloque de hielo al congelarse, que estalla al romperse; aliento que humea; pisadas en la nieve; chispas al patinar sobre el hielo.
  - Enemigos: niebla fría y destellos, y al morir estallan en trozos de hielo.
  - Decoración: destellos en los cristales y humo en las fogatas.
  - Carámbanos (servidor): estallido, esquirlas y anillo de escarcha.
- La Fortaleza ahora tiene luz propia: cielo rojo y ceniza.
- **Ajuste tras probarlo** (pantalla muy brillante y con tirones):
  - Glaciar al mediodía (cielo celeste, no naranja), con menos brillo y menos bruma.
  - Sin bloom, rayos de sol ni desenfoque extra.
  - Menos partículas: polvo, nieve barrida, ventisca y niebla de los enemigos.
  - Blanco de la ventisca más suave y montículos de nieve más chicos.
- **No se podía subir lomas ni rampas** (el resbalón también pisaba la velocidad en pendientes):
  - En pendientes se camina normal: solo se resbala en lo plano.
  - Los acantilados del Glaciar ahora son de roca, no de hielo.
- **Nieve con más textura:** se mezcla con costra (Salt), nieve pisada (Limestone) y rocas que asoman (Slate). Además los colores del terreno son más grises y azulados, para que la luz no los queme en blanco.
- **Texturas realistas de nieve y hielo:**
  - Imágenes de color, relieve y rugosidad en `assets/textures/glacier/`, subidas a Roblox.
  - En el place de la Arena están los materiales `NieveGlaciar` y `HieloGlaciar` en MaterialService, y reemplazan a Snow e Ice en todo el place.
  - No los sincroniza Rojo: viven en el place, así que hay que guardarlo.
- **Ataques que se ven sobre la nieve:** los avisos de área y los carámbanos del Glaciar pasan de celeste a rojo fuerte, y las zonas de escarcha a azul intenso. Las balas ya usaban el color de peligro.
- **Fogatas:**
  - Ahora son 9.
  - Cada una tiene un marcador 🔥 siempre visible, con la distancia, y una columna de luz naranja.
  - Con frío o ventisca los marcadores laten y el de la fogata más cercana se agranda.
- **Montañas del borde:**
  - En el Glaciar son gigantes y nevadas: 95 de alto, con picos blancos (`Config.Map.ThemeEdges`).
  - En todos los mapas hay paredes invisibles al pie, para no salir trepando (`Config.Map.BoundaryWalls`).
- **Enemigos de hielo con modelo propio** (`Server/IceLooks`):
  - Los que no tenían modelo usaban los genéricos de «Todos» (muñecos y zombies). Ahora se arman por código de hielo, cristal y luz:
    - Diablillo de escarcha: cuernos, garras y púas.
    - Guardián glacial: escudo, maza de hielo y núcleo brillante.
    - Caballero boreal: corona, capa translúcida, espada de luz y halo.
    - Garra helada: cangrejo con pinzas y ojos en tallos.
    - Centinela de escarcha: cristal flotante con un gran ojo.
    - Espectro de hielo: túnica rasgada y niebla.
    - Trozo de slime helado.
  - Si en EnemyModels hay un modelo con el mismo nombre, se usa ese.
- **Ataques con efectos** (`Client/IceWorld`):
  - Cada disparo enemigo sale con un anillo de escarcha, esquirlas, vaho y un destello de luz.
  - Cada área de ataque, al caer, hace brotar estacas de hielo del piso que se rompen en esquirlas y vaho.
- **Glaciar más legible** (antes «todo blanco» y no se entendía por qué perdías vida):
  - **Crepúsculo azul:** con la nieve en penumbra resaltan los enemigos, los avisos rojos, las fogatas y la aurora, que ahora es más intensa.
  - **Mecánicas de a una:** las oleadas 1 y 2 traen solo enemigos, los carámbanos empiezan en la 3 y la primera ventisca llega en la 5 (`FromWave`). Cada una se presenta con un cartel (atributo `GlacierTip`).
  - **Ventisca:**
    - Arriba hay una barra con «VENTISCA en N s» (atributo `BlizzardNext`) y, mientras sopla, «VENTISCA · N s», con la distancia a la fogata más cercana.
    - Oscurece la pantalla en vez de blanquearla. Dura 6 s y pasa cada 32 a 42 s.
  - **Por qué perdés vida:** arriba de la barra de vida aparece la causa, por ejemplo «Carámbano −20», «Disparo −14» o «Zona en el piso −8». `PlayerLife.damage` recibe la causa y la publica en el atributo `LastHurt` del jugador.
  - **Medidor de frío:** muestra «Te frena N%», la distancia a la fogata más cercana y parpadea «¡Te vas a congelar!» cuando estás por congelarte.
  - **Mapa:**
    - Un lago congelado grande a un costado del centro, con menos manchas de hielo sueltas.
    - Un anillo de bosques de pinos oscuros y rocas antes de las montañas.
    - Antorchas que marcan el camino desde el centro a cada fogata.
- **Menos enemigos pero más duros en el Glaciar:** hay campos nuevos por capítulo, `CountMult` y `Toughness`. En el Glaciar salen un 45% de los enemigos y cada común tiene el doble de vida. Los jefes no cambian.
- **Pruebas:** `test_modes` refleja el nuevo orden y `test_grab` acepta variantes del Atrapador.

## 2026-10-23 · Robo de vida y habilidades más moderados

- **Robo de vida** (espada y puños, `Config.Melee`):
  - baja de 4% a 1,5% del daño;
  - nuevo tope de 3% de la vida máxima por segundo (`LifestealMaxPerSecond`);
  - contra jefes rinde la mitad (`LifestealBossMult`).
- **Habilidades** (`Shared/Skills`, con sus textos):
  - Fuerza +20% → +12%; Cadencia 15% → 10%; Ojo de halcón 8% → 6%; Golpe brutal +50% → +35%.
  - Quemadura 30% → 15% por segundo (`Config.Projectiles.BurnFraction`).
  - Escudo de maná 12/8 s → 16/12 s; Reflejos 10% → 7%; Cadáver explosivo 40% → 25%.
  - Arco: Ojo del cazador 25% → 20%; Flechas explosivas 35% → 25%; Pulso firme 25% → 15%; Primera sangre 60% → 40%.
  - Espada: Ejecución 60% → 35%; Sed de sangre 2 → 1 de vida; Armadura 12% → 10%; Herida profunda 25% → 15%; Tajo veloz 150% → 100%.
  - Puños: Doble golpe 20% → 15%; Adrenalina 30% → 20%.

## 2026-10-23 · Nueva pantalla de capítulos y mapa sin forma de caja

- **«Elegí tu aventura»** (`LobbyUI`): tarjetas grandes en dos columnas.
  - **Arriba:** la imagen del reino (`Chapters › Banner`). Sin imagen, un degradé del color del capítulo con su ícono.
  - **Abajo:** «CAPÍTULO 0N», el nombre, una línea corta (`Tagline`) y el estado (victorias, «Disponible» o «Completá el capítulo anterior» con candado).
  - **Botón:** SELECCIONADO o EXPLORAR. Los capítulos bloqueados se ven apagados.
- **Imágenes:** 4 en `assets/ui/banners/` (bosque, ruinas, fortaleza y glaciar), ya subidas y puestas en `Chapters › Banner` (Desierto de los Reyes sigue sin imagen).
- **Cinemática del jefe:** `BossIntro` esperaba `GameState` dentro de `Remotes`, pero está en `ReplicatedStorage`. Por eso no se veía la cinemática ni sonaba el rugido.
- **`MapBuilder`:** las montañas del borde siguen un contorno redondeado e irregular (superelipse con ruido), con picos de alturas distintas y roca rugosa. Antes eran un anillo cuadrado de altura pareja.

## 2026-10-23 · Bolas de fuego de Azrakoth y entrada enfrentados

- **Proyectiles:**
  - Nuevos campos en los ataques: `KeepColor` (no usa el color de peligro global) y `VisualSize` (se dibuja más grande, sin agrandar la hitbox). Llegan por `EnemyAI.shoot` y `Combat.fireEnemyProjectile`.
  - Azrakoth tira bolas de fuego naranjas: tamaño visual 2,6 (1,8 en el rayo).
  - `ProjectileVisuals`: las bolas de fuego grandes llevan más llamas y chispas.
- **Entrada enfrentados:**
  - Al empezar la cinemática, `Waves` gira a cada jugador hacia el jefe y al jefe hacia el primer jugador.
  - Al terminar, `BossIntro` apunta la cámara al jefe (sirve en primera persona).

## 2026-10-23 · Golpes en área que se pueden leer

- **Áreas de Azrakoth:** el círculo rojo aparece casi al empezar el golpe y se llena durante 0,9 a 1,5 s. Antes salía 0,3 s antes de explotar. Afecta a 8 ataques: Juicio Carmesí, los remates de la Danza, la Caída del Serafín y las zonas de fuego.
- **`EnemyAI`:** en los ataques de área, la animación sincroniza el golpe con el estallido (aviso + `Delay`).
- **`Hazards.warn`:** marca cada círculo con `Warning`, `Radius`, `EndsAt` y `Total`.
- **`Client/HazardAlert`** (nuevo): si estás dentro de un círculo de peligro, muestra bordes rojos que laten, «¡SALÍ DEL CÍRCULO!», una flecha que apunta hacia afuera según tu cámara y una barra con el tiempo que queda. Sirve en primera persona y para todos los enemigos.

## 2026-10-23 · Cinemática de entrada de los jefes

- **`Intro` en `Data/EnemyTypes`:** campos `Anim`, `Duration`, `Title` y `Subtitle`. Azrakoth tiene 7,2 s: «AZRAKOTH — El Serafín del Eclipse Carmesí».
- **`Waves`:** al aparecer un jefe con `Intro`, llama a `PlayerData.startCinematic`, reproduce su animación (`BossAnim`) y publica `GameState.BossIntro` = «Título|Subtítulo|hora|duración».
- **`Progression.syncPause`:** también congela durante la cinemática. `ChoosingPaused` sigue indicando solo la elección de habilidades.
- **`Client/BossIntro`** (nuevo):
  - **Pantalla:** franjas de cine, color oscurecido y HUD oculto.
  - **Planos:** bajo desde el piso, primer plano del casco, plano abierto cuando se levanta y despliega las alas, y rugido con temblor y título.
  - **Saltear:** con Espacio, el botón A o tocando la pantalla.
  - **Cámara:** usa el atributo `Cinematic` para que `CameraController` suelte la cámara, como en `CrateCinematic`.
- Sin sonidos propios por ahora: los efectos de `AzrakothVFX` (ojos, alas, rugido) se disparan con las marcas de la animación.

## 2026-10-23 · Dash sin trabones

- **El problema:** el dash le pasaba el control del personaje al servidor (`SetNetworkOwner(nil)`). Durante el impulso la cámara seguía posiciones que llegaban de a saltos, y al devolverle el control al jugador el personaje pegaba un tirón.
- **`Client/Dash`:** ahora mueve el impulso en `PreSimulation`, con la velocidad de `Config.Dash`. Respeta el enfriamiento (`DashReadyAt`) y no se activa si el jugador está agarrado o muerto. Al terminar vuelve a la velocidad de caminar.
- **`Server/Dash`:** sigue validando el pedido (enfriamiento, derribo, agarres, NaN) y lleva la ventana del dash (invulnerabilidad, Corte en dash), pero ya no toca la dueñidad ni la velocidad.
- **`test_items_dash`:** actualizado (35/35 OK).

## 2026-10-23 · Más dificultad para los jefes del capítulo 1

- **Azrakoth:**
  - Vida: de 7000 a 20000.
  - Daño de los ataques: +30 % (contacto, de 26 a 32).
  - Pausas entre ataques más cortas.
  - Velocidad: 7, 8 y 10 según la fase (antes 5, 6 y 7).
- **Rey Slime:**
  - Vida: de 1100 a 3400. Al morir se divide en 3 slimes rojos.
  - Fase 1:
    - salta sobre el jugador y cae con una onda de veneno;
    - deja charcos de veneno que duran;
    - ráfagas radiales;
    - invoca.
  - Furia (desde el 60 %):
    - tres saltos encadenados;
    - lluvia de charcos por la arena;
    - áreas dobles;
    - triple ráfaga.

## 2026-10-23 · Corazones de vida

- **`Server/Hearts`** (nuevo):
  - Al morir, un enemigo común suelta un corazón con un 7 % de probabilidad. Los jefes y mini-jefes sueltan 3. Los invocados no sueltan.
  - El jugador herido que pasa cerca lo junta y se cura el 20 % de su vida máxima.
  - Duran 15 s y titilan los últimos 3.
  - Valores en `Config.Hearts`. Lo engancha `Run`: los suelta al morir el enemigo, los actualiza cada frame y los borra al terminar la partida.
- **`.gitignore`:** ignora `assets/*/output/roblox/` (exportaciones pesadas que se regeneran).

## 2026-10-23 · Azrakoth, jefe del capítulo 1 (oleada 10)

- **Azrakoth, Serafín del Eclipse** (`Data/EnemyTypes`) reemplaza al Guardián Treant como jefe de la oleada 10 del capítulo 1. El Treant sigue en el catálogo.
  - 7000 de vida y tres fases (70 % y 35 %). Usa los tipos de ataque que ya existen:
    - **Juicio Carmesí:** área bajo el jugador más una onda de proyectiles.
    - **Danza del Verdugo:** dos embestidas y un golpe en área.
    - **Tormenta de Alas:** abanico de plumas y zonas de fuego.
    - **Cadenas del Abismo:** círculos que estallan.
    - **Caída del Serafín:** se teletransporta y golpea con zona de fuego.
    - **Corazón del Eclipse:** anillos de proyectiles con aviso de 2 s.
    - **Legión de los Condenados:** invoca 4 esqueletos.
    - **Rayo del Eclipse:** aliento giratorio, solo en la fase 3.
- **Modelo:** `ServerStorage > EnemyModels > Azrakoth`, ya armado en el place Arena. Son las 43 piezas de `assets/azrakoth` unidas con Motor6D, más una raíz y un `Humanoid` para que `EnemyVisuals` lo trate como rig. Se escala a la altura `Height = 34`, que incluye las alas.
- **Animaciones:**
  - `Client/AzrakothAnimator` lo anima con `Shared/AzrakothAnimData`, exportado de Blender: Idle o Walk según se mueva, y la animación de cada ataque.
  - Cada ataque lleva `Anim`, y `EnemyAI` publica el atributo `BossAnim` ("Nombre|aviso|hora"). El cliente acelera o frena la animación para que el golpe coincida con el final del aviso.
  - `PhaseAnim` reproduce `PhaseTransform` al cambiar de fase.
  - `EnemyAnimator` ignora los modelos con el atributo `AnimData`.
- **Pelea solo:** `Alone = true` en `EnemyTypes`; en `Waves`, su oleada no trae otros enemigos ni eventos.
- **Muerte:** `DeathAnim`/`DeathTime` en `Enemies.damage`. La caja pasa a `workspace.BossCorpses`, sin barra ni colisión, y se desploma con la animación de muerte antes de borrarse.
- **Animación más viva** (`AzrakothAnimator`):
  - Cada hueso sigue su pose con un resorte, y alas y telas llegan tarde.
  - La velocidad del jefe se suaviza; antes alternaba entre Walk e Idle en cada cuadro y se veía quieto.
  - Cuando está quieto, respira y mira alrededor.
- **Efectos** (`AzrakothVFX`): ondas, rocas, columnas de fuego, círculos, rayo del halo, destellos y temblor de cámara, disparados por las marcas de cada animación.
- **Pruebas:** `test_integration` y `test_rewards` esperan ahora a Azrakoth (35/35 OK). **Sin probar en Studio.**

## 2026-10-22 · Seraphiel, Ángel Celestial (skin Mythic) y la Espada Celestial

- **Seraphiel** (`Shared/CrateItems`, Mythic, personaje): sale en los cofres Epic (0,3%), Legendary (3,5%) y Secret (15%), igual que los otros tres Mythic. Las tablas siguen sumando 100: se les sacó a Leñador (Epic), Paladín (Legendary) y Paladín, Rey Dorado y Valquiria (Secret).
- **Traje de cuerpo completo** (`Shared/CrateLooks`, `Body = "Seraphiel"`): 22 mallas en `ReplicatedStorage > CrateAssets > Looks > Seraphiel` (viven en el place; salen del modelo hecho con `Seraphiel_Blender.py`):
  - casco con corona, armadura, hombreras, brazales, guanteletes, musleras, grebas, botas, faldones con cintas y seis alas;
  - cada malla tiene `AttachTo`, `AttachOffset` y `Rest`, calculados con un cuerpo R15 de bloques escalado como el traje (`BodyScale.Height = 1.235`).
  - El modelo importado quedó de respaldo en `ServerStorage > Seraphiel_Importado`.
- **Partes que se mueven** (`BodySway`, nuevo en `CrateLooks`): las piezas de un traje de cuerpo completo pueden balancearse.
  - Las seis alas aletean y se abren al saltar, como las del Demonio.
  - Los faldones se mecen poco (`LavaSkinFx`, nuevo tipo `"Skirt"`, para que no atraviesen las piernas).
- **Efectos:** destellos dorados en la corona y las alas grandes, chispas celestes y una luz turquesa suave en el pecho, y estela de luz en los faldones. Los cristales, ojos, núcleo y puntas de plumas brillan con la máscara de brillo de cada `SurfaceAppearance`.
- **Flechas de luz** (`Shared/SkinFx`): vara nacarada, punta turquesa, estela dorada que termina en celeste, brasas doradas y explosión de luz al pegar. Usan el estilo nuevo `Celestial` de `FxStyles`, con las texturas de respaldo de Roblox teñidas de dorado (todavía sin texturas propias).
- **Espada Celestial** (`Shared/Weapons`, `CelestialSword`): arma especial que **viene con el skin**, porque su `Prize` es `Seraphiel`.
  - Juega como la espada (habilidades y animaciones), con sus números: daño ×2,35, alcance 13 y arco 150°. Usa los efectos del estilo `Celestial` (tajo, Torbellino y Juicio dorados).
  - Modelo en `ReplicatedStorage > WeaponModels > CelestialSword`: la malla de la espada, con `Handle`, `Guard` y `BladeAura` invisibles para el agarre y la estela.
  - `Weapons.unlockedBy(prizeId)` es nuevo. Al ganar Seraphiel en una caja, `CrateService` publica las armas y la espada ya aparece en el menú "Arma". Si no tenés el skin, el servidor responde "viene con el skin Seraphiel".
- **Panel F2:** "Darme y equipar Seraphiel (con la Espada Celestial)".
- **Pruebas:** `test_weapons`, nueva "Espada Celestial: viene con el skin Seraphiel" (35/35 archivos OK). Probado en Studio:
  - en el lobby, el traje completo con las 22 piezas y las 7 soldaduras que se balancean;
  - en partida con la Espada Celestial, 23 bajas en un intento;
  - en partida con arco, las flechas con punta turquesa y los impactos;
  - sin errores en la consola.

## 2026-10-22 · Flechas con la skin: Demonio Ígneo

- **Flechas de fuego** para quien tiene puesto el Demonio Ígneo (`Client/SkinArrowFx`, nuevo):
  - Vara de basalto, punta de neón naranja y estela de fuego más ancha y larga.
  - En vuelo: llamas (flipbook del estilo Inferno), brasas y una luz que acompaña a la flecha.
  - Al disparar: chispazo en el arco. Al pegar: llamarada, anillo, destello, humo y un fogonazo de luz. Si la flecha llega al final de su alcance sin pegar, se apaga con unas chispas.
  - Las plumas siguen diciendo de quién es la flecha (tuya, compañero, gigante).
  - Calidad baja (celulares): solo los colores de la vara y la punta, y chispas al pegar; sin partículas ni luces en vuelo. Hasta 6 luces de flechas a la vez.
- **`Shared/SkinFx` (nuevo):** colores y efectos de cada skin en un solo lugar. Las pisadas, el aura y la estela de `LavaSkinFx` ahora toman los colores de acá (Demonio Ígneo, Mago Cósmico y Necromante). Para darle flechas propias a otra skin alcanza con sumarle `Arrow`.
- Todo es visual y lo dibuja cada cliente: no cambia el daño ni lo que hace el servidor.
- Pruebas: `test_skinfx` (6): datos de cada skin, la skin sale del atributo `CrateLook`, solo las flechas del que la tiene puesta, vestir y limpiar flechas del pool, calidad baja y tope de luces (34/34 archivos OK). Probado en Studio: en partida las flechas salen vestidas (vara, punta, estela, llamas y luz) y los impactos aparecen; se vio en pantalla una ráfaga de prueba con el mismo módulo. Sin errores en la consola.

## 2026-10-21 · Ciudadela y Arena separadas: grupos y cola rápida

- **Dos places, el mismo código.** El rol lo decide `Server/Places`:
  - **Ciudadela** (lobby, hasta 20 jugadores): cada uno está en su grupo y nadie te arrastra a su partida.
  - **Arena** (servidor privado por grupo): recibe al grupo teletransportado, juega y lo devuelve.
  - En Studio, o mientras `Config.Places.ArenaPlaceId` sea `0`, el grupo juega en el mismo servidor, como antes.
- **Grupos** (`Server/PartyService`, nuevo): invitar desde la lista de jugadores, aceptar o rechazar (la invitación vence en 30 s), salir y expulsar.
  - El líder elige el capítulo. Cuando todos están LISTOS, salen juntos con la cuenta de 5 s.
- **Cola rápida (BUSCAR GRUPO):** junta grupos y jugadores sueltos del mismo capítulo hasta 4.
  - Si en 20 s no se llena, sale con los que haya.
  - Si alguien cancela en la cuenta, los demás vuelven a la cola sin perder su lugar.
- **Viajes** (`Server/Teleporter`, nuevo): servidor reservado con los datos del grupo (capítulo e integrantes) y reintentos. Si el viaje falla, avisa y el grupo queda en la Ciudadela.
- **En la Arena** (`MatchManager`):
  - Espera a que llegue todo el grupo (o 25 s como máximo) y arranca solo con una cuenta de 3 s.
  - Al terminar, los que eligen **¡OTRA!** se quedan y juegan de nuevo; el resto vuelve a la Ciudadela.
  - Quien entra a la Arena sin viaje vuelve a la Ciudadela.
- **Interfaz:**
  - Panel **GRUPO** con lugares libres, botones Invitar, Salir y Expulsar, y la ventana "Invitar al grupo".
  - Tarjeta de invitación recibida con tiempo.
  - Botón **BUSCAR GRUPO** y JUGAR con el tiempo en cola y Cancelar.
  - En la Arena: "Preparando la batalla (2/3 llegaron)".
- **`TravelScreen.client`** (nuevo): pantalla de viaje "Viajando a la Arena" o "Volviendo a la Ciudadela" que se ve durante el teletransporte.
- **Pruebas nuevas:** `test_parties` (grupos, invitaciones, cola, viaje falso) y `test_arena_place` (llegada, espera, OTRA y vuelta). Las pruebas viejas usan el modo "Classic" (`TestClassicLobby` en `tests/mocks.luau`).

## 2026-10-21 · Lobby nuevo: la Ciudadela

- **Ciudadela** (`Workspace/Ciudadela`, armada en Studio: vive en el place): una isla flotante con una plaza de castillo.
  - Murallas almenadas, 4 torres, portón y fuente con cristal mágico, faroles y árboles.
  - Al norte, el **Portal de batalla**: su prompt JUGAR te pone LISTO.
  - Al oeste, el mercado: el **Mercader** abre la Tienda y el **Capitán de la Guardia** abre las Misiones, con un "!" cuando hay para cobrar.
  - Al este, la **vitrina** con las 3 skins míticas girando y el arco al **patio del tesoro**, que es la plaza de cajas rehecha en mármol con alfombra roja.
  - Los modelos detallados (fuente, puesto, tablón, faroles, árboles, torre, portón y NPCs) se generaron con IA y la biblioteca está en `ServerStorage/CiudadelaModelos`.
- **Tablas de récords**: top 10 global de nivel de cuenta y de piso de la torre (OrderedDataStore). Sin acceso a DataStore muestran a los jugadores del servidor.
- **`Server/LobbyWorld`** (nuevo): NPCs, portal, vitrina y tablas. **`LobbyWorld.client`** (nuevo): prompts, vitrina que gira y aviso de misiones.
- **`Lobby`**: con la Ciudadela usa su `LobbySpawn` y no arma la plaza vieja. **`CratePlaza`**: con la Ciudadela arma solo las plataformas. **`Atmosphere`**: sin luz volcánica en el patio del tesoro.
- **Interfaz del lobby rehecha** (`LobbyUI`), con el centro libre para ver la ciudadela:
  - Tarjeta del jugador con avatar, nivel y barra de XP.
  - Monedas en chips.
  - Botonera vertical con avisos de talentos y misiones.
  - Equipo compacto con avatares.
  - Tarjeta **BATALLA** con el capítulo elegido y una ventana para cambiarlo.
  - Botón JUGAR con brillo.
- `RewardsUI`: arreglado un "Label" suelto que se veía en pantalla.

## 2026-10-21 · Skins Mago Cósmico y Necromante

- **2 premios Mythic nuevos:** Mago Cósmico (`CosmicMage`) y Necromante (`Necromancer`). Salen de las cajas Epic, Legendary y Secret con las mismas chances que el Demonio Ígneo.
- **Trajes de cuerpo completo** (`Body` en `Shared/CrateLooks.lua`): 16 mallas, una por parte R15 más el báculo, en `CrateAssets/Looks/<Id>`.
  - En el avatar se esconden las partes de Roblox y se sueldan las mallas.
  - El avatar crece un 23% (`BodyScale`) para que las mallas calcen a su tamaño original.
  - La emisión de colores está horneada en la textura de color (`src/assets/<skin>/generadas`).
- **Partículas nuevas:** `Stars` (estrellitas) y `Wisps` (espíritus de humo). Todas aceptan `Colors`.
- **`LavaSkinFx`:** pisadas, aura, estela y explosión al equipar en violeta (mago) y verde (necromante).
- Panel F2: **Darme y equipar Mago Cósmico** y **Darme y equipar Necromante**.

## 2026-10-21 · Skin Demonio Ígneo con mallas, y unión de fase2 con detalles

- **Demonio Ígneo con modelos 3D** (`Shared/CrateLooks.lua`): el traje ahora son 12 mallas (máscara, torso, capa, alas, hombreras, brazales, grebas y taparrabos) con textura, brillo de lava, relieve y rugosidad. Viven en el place (`ReplicatedStorage/CrateAssets/Looks/FireDemon`); las fuentes están en `src/assets/demon`.
  - Campos nuevos de las piezas: `Mesh`, `Glow`, `Fx` (`Flames`, `Embers` y `Smoke`), `Sway`.
- **`LavaSkinFx`** (cliente, nuevo):
  - El brillo late.
  - Las alas aletean suave y se abren al saltar, y la capa se balancea.
  - Pisadas de lava, aura en el piso, estela en el dash y explosión de brasas al equiparlo.
- Panel F2: **Darme y equipar Demonio Ígneo**.
- **Unión con fase2:** las cajas dan solo personajes y los huevos, solo mascotas.
  - Los premios nuevos de fase2 se repartieron así: Escudero, Pirata, Druida, Valquiria y Caballero del Vacío a las cajas; Búho a los huevos.
  - Conejo queda como mascota Common.
  - La caja de armas es un cofre de monedas (10.000).
  - La fila de cofres de la tienda se achica sola si no entran.

## 2026-10-21 · Élites con cofre, momentos horda, metas de equipo y maestría por arma

- **Élites** (`Server/WaveEvents.lua`, `Config.Events.Elite`): desde la oleada 2, algunos enemigos comunes salen potenciados: más grandes, con aura violeta, ×7 de vida y un rasgo (Veloz, Blindado, Furioso o Gigante) en su cartel. Dan más XP y al morir sueltan un cofre (Rara o mejor). Más élites cuanto más avanzada la oleada.
- **Momentos horda** (`Config.Events.Horde`): desde la oleada 3, a veces a mitad de oleada llega una avalancha de enemigos débiles desde todos lados, con cartel, contador y borde rojo. La oleada no termina hasta superarla, y superarla da oro y un cofre al equipo. Nunca en la oleada del jefe.
- **Metas de equipo** (`Config.Events.Goals`): una por oleada desde la 2, arriba al centro con progreso y tiempo.
  - Maten N enemigos en 30 s.
  - Maten al élite marcado en 25 s.
  - Abran 2 cofres.
  - Que nadie caiga.
  - Cumplirla da oro (a veces gemas) y un cofre para todos.
- **Maestría por arma** (`Shared/Mastery.lua`, `Server/MasteryService.lua`): por familia (arco, espada, puños; las especiales suman a su base).
  - Se gana XP al terminar cada partida; 10 niveles.
  - +2% de daño por nivel, más crítico en los niveles 5 y 10.
  - Títulos Aprendiz, Experto y Maestro, con borde de color en la carta del arma.
  - Se ve en el menú Arma y en los resultados de la partida.
- **Habilidades con candado**: cada arma tiene 2 habilidades de la segunda tanda que piden maestría. Su épica pide nivel 3 y su legendaria nivel 5 (Anillo de flechas / Flecha fantasma, Tajo veloz / Danza de espadas, Golpe sísmico / Puño del dragón). Hasta entonces no salen en las ofertas y en el menú Arma aparecen con 🔒.
- **Perfil versión 11**: guarda la maestría. Para no quitarle habilidades de golpe a quien ya jugaba, el arma elegida arranca con la mitad de sus bajas históricas como XP (como mucho, nivel 5).
- **Sonidos nuevos** para élites, horda, metas y subir de maestría (`Shared/Sounds.lua`).
- Panel F2: Aparecer élite, Momento horda, Meta de equipo y +1 nivel de maestría.
- **Pruebas**: `tests/test_events.luau` (16 nuevas). Se arreglaron 3 pruebas viejas que habían quedado desactualizadas con los modos y la Katana Carmesí. Ahora pasan las 31.

## 2026-10-21 · Efectos propios para la Hoja Infernal y la Katana Carmesí

Ya no son un cambio de color de los de escarcha: cada arma tiene formas y comportamientos propios.

- **Texturas con forma propia** (`tools/vfx_shapes.py`, usado por `gen_vfx_textures.py`):
  - Infernal: llamas con varias lenguas y brasas, humo negro iluminado desde abajo, tajo grueso con llamas en el borde, pared de fuego, anillo con púas, cráter de lava, explosión irregular y cometa.
  - Carmesí: espinas que se quiebran, hilos de humo en espiral, tajo de navaja con núcleo negro, doble hélice, anillo de esquirlas, sigilo hexagonal, estrella de agujas y aguja.
- **Comportamientos propios** (`AnimeFx`, campo `Variant` de `FxStyles`):
  - Infernal: cada tajo deja fuego en el piso, el remate del combo levanta 4 columnas de fuego en línea, el torbellino suma un tornado de fuego, cada golpe explota y el Juicio es un meteorito que cae y deja un cráter.
  - Carmesí: cada tajo deja un corte en el aire con núcleo negro que se rompe en esquirlas, cada golpe marca una X roja, el torbellino hace brotar un anillo de espinas y el Juicio suma un anillo de espinas grande a la esfera que explota.
- Hay que reimportar las 8 texturas infernales (cambiaron de forma) e importar las 8 carmesí.

## 2026-10-21 · Katana Carmesí

- **Katana Carmesí** (`CrimsonKatana`, mítica, caja de armas): tercera arma especial, original.
  - Hoja negra curva con el filo y las vetas rojas brillantes, guarda cuadrada con gema roja y atado rojo y negro (`tools/build_crimson_katana.luau`).
  - Juega como espada: más pesada que la de escarcha y más rápida que la infernal.
- **Estilo `Crimson`** (`FxStyles`): paleta roja con contorno casi negro (`tools/gen_vfx_textures.py`, 8 texturas en `assets/vfx`). Trae dos rasgos nuevos que dibuja `AnimeFx`:
  - `BodyAura`: llamas carmesí envolviendo a todo el personaje, en el lobby y en partida, también vistas por los demás. Tu propia primera persona no las muestra, para no tapar la vista.
  - `Burst`: el remate del combo y el Juicio son una esfera roja que crece y explota, con onda en el piso, llamas, humo y la pantalla teñida de rojo si estás cerca.
- La caja de armas queda en 34/33/33 y sigue sin repetir.
- Panel F2: botón **Todas las armas especiales** para probarlas sin abrir cajas.

## 2026-10-21 · Glaciar y Desierto, Torre infinita, Desafío diario, 24 habilidades y modelos de enemigos

- **Modelos de todos los enemigos** generados con IA en Studio (`ServerStorage/EnemyModels`, viven en el place), separados en partes para animarlos.
- **Animaciones** (`EnemyAnimator`, cliente):
  - Los que caminan balancean piernas y brazos según la velocidad.
  - Los slimes se estiran, saltan en arco y se aplastan al caer con rebote; quietos, respiran.
  - Lo decide el atributo `Gait` del servidor (`Enemies.gaitOf`).
- **Habilidades:** 24 nuevas, 51 en total.
  - 6 comunes: Vampirismo, Toque helado, Rayo en cadena, Escudo de maná, Reflejos y Cadáver explosivo.
  - Una **segunda tanda de 6 por arma** (`Tier = 2`, desde el nivel 6, con aviso en el HUD), incluida una legendaria nueva por arma: Flecha fantasma, Danza de espadas y Puño del dragón.
  - Efectos en `SkillEffects` (servidor) y `SkillVisuals` (cliente, `Remotes.SkillFx`). Los enemigos ahora pueden estar frenados (`slowUntil`) o vulnerables (`vuln`).
- **Sinergias con bono:** las 14 de antes ahora dan un bono real y hay 15 nuevas (29). Se aplica una vez por partida y se ve en el cartel.
- **Capítulos 4 y 5:** Glaciar Eterno y Desierto de los Reyes.
  - 16 enemigos nuevos, 2 de ellos mini jefes y 2 jefes: Yeti, Reina de Hielo, Gólem de arena y Faraón Eterno.
  - Terreno, decoración, luz y clima propios: nieve y arena.
- **Modos** (`Shared/Modes.lua`):
  - **Torre infinita:** pisos sin fin que cambian de ambientación cada 10, con jefes, récord y premios por hito.
  - **Desafío diario:** ambientación y 2 modificadores por día, con premio la primera victoria del día.
  - `Waves.setMode`, `Run.start(..., mode)` y `Rewards` (torre sin tope de pisos, premio diario).
  - Perfil **versión 10** (`Modes.DailyWonDay`).
- **Lobby:** la lista de capítulos tiene scroll y una sección MODOS. Los botones de abajo ya no se pisan con JUGAR.
- Pruebas nuevas: `test_skills_t2.luau` y `test_modes.luau`. Probado en Studio:
  - torre hasta el piso 11, con cambio a Ruinas;
  - habilidades nuevas en partida (rayo, esquiva y onda cortante);
  - sin errores en la consola.

## 2026-10-21 · Misiones, tienda, más premios y Hoja Infernal

- **Misiones diarias y semanales** (`Shared/Missions.lua`, `MissionService`, `Remotes.MissionRequest`):
  - 3 diarias y 3 semanales por jugador, sorteadas de 8 cada una. Siempre son las mismas en el período y se reinician a las 00:00 UTC (las semanales, los lunes).
  - Tipos: bajas, bajas con un arma, oleadas, jefes, victorias, partidas, cofres, oro y cajas abiertas.
  - El progreso lo cuenta el servidor al terminar la partida (`MatchManager`; abandonar no cuenta) y al abrir cajas.
  - Premios en oro, gemas y a veces piedras. El atributo `MissionsClaimable` alimenta el aviso del botón.
- **Tienda del lobby** (`Shared/ShopDefs.lua`, `ShopService`, `Remotes.ShopRequest`), sin Robux:
  - 4 ofertas de equipo por día, distintas por jugador, sin míticas.
  - Cambios gemas→oro y oro→piedras con límite diario.
  - Cofre de runas.
  - El servidor valida lobby, frecuencia, inventario y monedas. Si la entrega falla, devuelve lo cobrado.
- **Ventana Tienda/Misiones** (`ShopUI`, nuevo) con dos pestañas. En el lobby, el botón **Tienda** queda activo y hay un botón nuevo **Misiones** con aviso.
- Perfil **versión 9**: `Missions` y `Shop`, con reconcile que limpia datos rotos. `PlayerData` cuenta los cofres abiertos en la partida.
- **8 premios nuevos** (27 en total), todos repartidos en las tablas de `Crates.lua`, que siguen sumando 100:

  | Premio | Rareza |
  |---|---|
  | Escudero, Conejo | Common |
  | Búho, Pirata | Uncommon |
  | Druida | Rare |
  | Valquiria | Epic |
  | Dragoncito | Legendary |
  | Caballero del Vacío | Mythic |

- **Hoja Infernal**, segunda arma especial (`InfernoBlade`, mítica):
  - Juega como espada: más lenta que la katana, pero pega más y llega más lejos.
  - Estilo de efectos `Inferno` (fuego rojo y naranja). Paleta `inferno` en `tools/gen_vfx_textures.py` y 8 texturas en `assets/vfx`. Hasta importarlas usa las de respaldo.
  - Modelo con `tools/build_inferno_blade.luau`.
  - La **caja de armas** queda 50/50 entre la katana y la hoja. **No repite**: tira solo entre las armas que todavía no tenés.
- Los colores de la estela y del "impact frame" salen del estilo (`Core`, `Deep`, `Flash` en `FxStyles`), ya no son celestes fijos.
- **RunLog:** el resumen suma oro por minuto, gemas y piedras promedio por capítulo.
- **README › Economía:** ingresos por capítulo, precios de referencia, cómo recalibrar con RunLog y el análisis del bono de las mascotas, que queda igual (+2% a +20%; el riesgo es vender la caja Secret por Robux).
- Pruebas nuevas: `test_missions.luau` y `test_shop.luau`. `test_crates` prueba que la caja de armas no repite.
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
