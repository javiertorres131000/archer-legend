# Análisis y continuidad · 9 de octubre de 2026

## Punto de partida verificado

El repositorio tenía completas las etapas 1–6: combate y jefes, tres capítulos, cooperativo de hasta cuatro jugadores, lobby, perfiles con bloqueo de sesión, monedas y recompensas. También estaban el mapa procedural de 300×300 con relieve y luz de día, disparo caminando, hordas, orbes de XP, cofres y enemigos dorados. Las doce suites originales pasaban.

No había objetos pasivos de partida ni inventario permanente. Los cofres ofrecían otra habilidad. La selección de habilidades detenía el disparo, otorgaba inmunidad y pausaba la simulación si todos elegían. El límite de 110 enemigos no incluía correctamente los grupos ni las invocaciones. README y arquitectura conservaban descripciones antiguas de noche, puertas y cantidades de contenido.

## Responsabilidades del código

| Área | Archivos principales | Estado |
| --- | --- | --- |
| Ciclo y cooperativo | `MatchManager`, `Run`, `PlayerData`, `PlayerLife`, `Lobby` | Funcionando; una partida por servidor; quien llega tarde espera en el lobby |
| Mundo | `Arena`, `MapBuilder`, `Ground` | Relieve procedural y mapas manuales; altura consultada en grilla |
| Amenazas | `Enemies`, `EnemyAI`, `Data/EnemyTypes`, `Waves`, `Hazards`, `Boss` | 40 tipos; cinco roles nuevos con debut progresivo; límite de invocaciones y separación en grilla |
| Combate y progresión | `Combat`, `Progression`, `Skills`, `Dash` | Disparo caminando, XP compartida, once habilidades, elecciones con pausa global, dash validado en servidor |
| Objetos temporales | `RunItems`, `ItemService`, `Chests`, `Orbs` | Diez objetos acumulables, aura, rayos, explosiones y sinergias; reinicio al terminar |
| Permanencia | `Profiles`, `Rewards`, `Loot`, `ChapterUnlocks`, `Equipment`, `EquipmentDefs` | Perfil v2 compatible con v1; seis espacios, dos conjuntos, niveles y fusión |
| Presentación | `Hud`, `LobbyUI`, `EquipmentUI`, `RewardsUI`, `RarityVisuals`, `Pickups` | UI de equipo activa; cartas centradas; colores por rareza; míticos con arcoíris |
| Efectos y rendimiento | `ProjectileVisuals`, `CombatText`, `Juice`, `ScreenEffects`, `ItemEffects`, `FxQuality`, `Performance` | Proyectiles visuales reutilizados; efectos de objetos limitados; diagnóstico de FPS optativo |
| Audio y cámara | `Sounds`, `Sfx`, `CameraController`, `Atmosphere` | Primera persona por defecto, cenital opcional; sonidos básicos reemplazables |

## Separación de progresiones

El perfil conserva equipo, niveles de equipo, monedas, capítulos y récords. Las habilidades y objetos temporales sólo existen en `PlayerData`; se borran al limpiar la partida. Al empezar se crea una base nueva y se aplica una sola vez el equipo elegido. Los multiplicadores temporales actúan sobre esa base.

El equipo tiene topes para daño (+30%), vida (+40%), velocidad (+15%), imán (+40%) y crítico (+10 puntos porcentuales), antes de bonos de conjunto. Un conjunto de seis Brasas comienza con fuego, pero no otorga las demás habilidades de la partida. Los servidores con código anterior detectan el perfil v2 como futuro y no lo sobrescriben.

## Validación y límites prácticos

Las pruebas ejecutan módulos reales con una API Roblox simulada. Cubren estado, transacciones, persistencia, peticiones malformadas, límites de acumulación, daño de pasivos, sinergias y presupuesto de invocaciones. Las quince suites pasan y todos los archivos Luau de `src` compilan sin errores de sintaxis. Esto no equivale a un análisis completo de tipos con las definiciones de Roblox. Ninguna de estas comprobaciones demuestra calidad visual, fluidez en móvil ni replicación física del dash.

Para medir en Studio: `Config.Debug.ShowPerformance = true`. El panel muestra FPS del cliente, peor frame del segundo, enemigos y proyectiles. Comparar solo y cuatro jugadores; probar un dispositivo móvil real además del emulador. Mantener el máximo de 110 hasta tener mediciones. Las duraciones de partidas con bots invulnerables sirven para detectar regresiones; el objetivo de 8–10 minutos requiere calibración jugando con daño real.

## Qué sigue

1. Probar sensibilidad de cámara, lectura de avisos, dash con latencia, cartas centradas en móvil y fuerza de las sinergias. Ajustar daño, frecuencia y alcance con datos de partidas.
2. Mejorar navegación: hoy los enemigos siguen la altura pero atraviesan decoración y suben acantilados. Resolverlo con obstáculos simples o rutas locales limitadas antes de agregar más modelos.
3. Etapa 8: economía de gemas, talentos/runas, reciclaje de equipo, misiones y tienda sin monetización. El inventario tiene un tope de 150; falta reciclaje para evitar saturación a largo plazo.
4. Etapa 9: modelos con siluetas reconocibles, animaciones y más sinergias, conservando colores de peligro separados de los efectos propios.
5. Pulido: reemplazar sonidos, medir red y FPS, ajustar primer arranque del terreno, controles con mando y móvil, y probar bloqueos de perfil entre servidores reales.

Los servidores con partidas activas necesitan detener la prueba y volver a iniciarla para cargar módulos nuevos. Rojo sincroniza archivos, pero no reinicia los módulos que Roblox ya cargó.
