# Arquitectura prevista — no implementada en etapa 1

No se modifica el juego activo en esta entrega. El miniboss aún no tiene combate funcional.

Config: 9000 HP base, 2–4 jugadores, 2 fases, objetivo 4–6 minutos sujeto al DPS real. Cooldowns iniciales: martillo 12s, meteoritos 18s, rayo 22s, prisión 25s, escudo 35s, pilares 20s. Sobrecarga una vez al 50%.

Controller/StateMachine: autoridad servidor, estado único con token de cancelación por acción, limpieza al morir y cambio de fase. Targeting filtra jugadores vivos de la partida. Hitboxes calcula impactos en servidor y deduplica por acción/jugador. Abilities implementa las siete habilidades. Phases controla umbrales. WeakPoints recibe impactos confirmados por el servidor de armas, jamás un booleano enviado por el cliente. Rewards entrega una sola vez por encuentro. Animations sincroniza presentación. VFXClient reproduce únicamente eventos visuales.

Mecánica de precisión futura configurable: impactos requeridos, ventana de exposición, duración del stun, multiplicador de daño y cooldown. Escudos tienen HP independientes; el núcleo solo queda expuesto en estados autorizados. Los pilares deben limpiar piezas y colisiones al cancelar; el rayo requiere raycast contra obstáculos válidos.

Se integrará con los sistemas reales de Leyendas de Flechas después de aprobar el modelo; no crear una segunda ruta insegura de daño en paralelo al servidor de armas.
