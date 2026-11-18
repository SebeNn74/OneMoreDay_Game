# ONE MORE DAY - GAME

Roguelike 2D top-down en pixel art. Motor: Godot 4.x (GDScript).

## Resolución
Interna 640x360, ventana 1280x720, filtro de textura Nearest.

## Dónde guardar cada cosa
	assets/sprites/player        -> sprites del protagonista (P3)
	assets/sprites/npcs          -> personajes secundarios (P3)
	assets/sprites/enemies       -> hostiles (P3)
	assets/sprites/environment   -> tiles, objetos y fondos (P3)
	assets/ui                    -> iconos, marcos y fuentes (P5)
	assets/audio/sfx             -> efectos de sonido (P5)
	assets/audio/bgm             -> música y ambientes (P5)
	core/
	data/                        -> recursos configurables .tres (stats, movimiento...)                        -> Autoloads globales (P1)
	scenes/<etapa>/              -> escenas por etapa del día
	scripts/utils/               -> utilidades compartidas
	scripts/simulation_bridges   -> conectores de los modelos de simulación (P1/P2)
	tools/                       -> scripts de editor (ej. generador de SpriteFrames)

## Convenciones
- Código, comentarios y nombres de archivo en inglés. Solo el texto visible al jugador va en español.
- Archivos y carpetas: snake_case. Nodos y clases: PascalCase. Constantes: UPPER_SNAKE_CASE.
- Tipado estático siempre. Privados con prefijo _.
- Sin números mágicos: constantes o archivos .tres en data/.

## Glosario
dinero=money, energía=energy, tiempo=time, victoria=victory, derrota=game_over,
ida=commute, trabajo=work, vuelta=return

## Escala visual
- Resolución interna 640x360, un escenario por pantalla.
- Los personajes (protagonista, NPC, hostiles) se dibujan a 16x24 y se muestran con
  scale 2 en su nodo de sprite.
- Celda de los agentes (hostiles): 32 px, igual que una casilla de arte mostrada x2 (GridUtils.CELL_SIZE).

## Autoloads (orden de carga)
EventBus, StatsManager, GameManager, Simulation, SceneManager.

## Capas de física 2D
1 world, 2 player, 3 npc, 4 enemy, 5 interactable, 6 decoration,
7 hitbox, 8 hurtbox, 9 detection, 10 projectile.
Constantes en scripts/utils/physics_layers.gd. Los nombres están en
Project Settings > Layer Names > 2D Physics.

## Flujo del día
- El orden de escenas se define en data/levels/day_sequence.tres (DaySequence).
- SceneManager (Autoload): start_day(), finish_day(victory), get_current_step().
- Cada nivel emite EventBus.level_completed desde su ExitZone.
- Las escenas de nivel son heredadas de base_level.tscn. Se generan con
  tools/generate_level_scenes.gd (no sobrescribe las existentes).

## Unidades
- Dinero: 1 unidad = $1.000 COP (inicio: 30 = $30.000). La interfaz muestra el valor x 1000.
- Energía y tiempo: 0-100.
- Derrota: cualquier recurso llega a 0.

## Jerarquía de base_level.tscn
- World/Background: Floor y Walls (arte, origen en la esquina superior izquierda, Centered desactivado).
- World/Collisions: WallRects (paredes como lista de rectángulos). World/Props: decoración plana sin colisión.
- World/Interactables: objetos del suelo (celular, monedas). Se dibuja debajo de Entities.
- World/Entities (Y-sort): Player, NPC, hostiles y muebles (Prop). Todo lo que se ordene con el jugador va aquí.
- World/Triggers: ExitZone y EventZone.
- Setup: LevelBounds y SpawnPoint. UI: HUD, pausa y notificaciones. Debug: solo en builds de depuración.

## Simulación (P2)
- Autoload Simulation (core/simulation.gd): única entrada a los 5 modelos.
- Modelos en scripts/simulation/, parámetros en data/simulation/ y data/events/.
- Prueba: godot --headless --path . -s res://tools/simulation_self_test.gd
- Monte Carlo (modelo 3): los eventos se sortean con Metropolis-Hastings (MCMC, MetropolisSampler).
  EventCatalog.mcmc_steps = 10 pasos por sorteo; 0 vuelve al sorteo directo (Monte Carlo clásico).
- Módulos standalone en simulation_standalone/ (Godot lo ignora por .gdignore). Modelo 3:
  python simulation_standalone/jimenez_poveda_modelo3_montecarlo_mcmc.py (validación + gráficos en salidas_modelo3/).

## Dinámica de recursos (modelo 5)
- PlayerSimulationBridge (hijo de Player) reporta la actividad a Simulation cada frame y aplica el factor de fatiga a Player.speed_multiplier.
- Simulation solo aplica flujos en frames donde el jugador reportó, con flows_enabled y con el estado PLAYING. No hay flujos en fundidos, pausa ni menús.
- BaseLevel.consumes_resources = false para niveles sin consumo (la casa).
- Player.is_controllable() es el único punto donde se bloquea al jugador.

## Eventos y celular
- 1 EventZone (scenes/global/event_zone.tscn) = 1 evento. Eventos por nivel: ver Excel, pestaña 5.
- EventRunner.trigger(stage): sortea (Simulation), muestra el texto y aplica los efectos.
- EventBus: notification_requested(text) abre el cuadro; game_event_triggered(event) es para logs y finales.
- Estado DIALOG: jugador bloqueado y sin flujos, sin pausar el árbol. Todo diálogo debe entrar y salir de ese estado.
- Si un evento agota un recurso, la derrota espera a que se cierre la notificación.
- La salida de la casa se desbloquea al interactuar con el celular (HomeLevel).

## Decisiones y NPC
- Datos: DecisionDefinition (frase + opciones) y DecisionOption (texto + efectos) en data/decisions/.
  Se generan desde la tabla de tools/generate_decision_definitions.gd (espejo de la pestaña 4 del Excel).
  Para cambiar valores: editar la tabla y volver a ejecutar la herramienta (sobrescribe los .tres).
- NPC: scenes/npcs/npc.tscn (Interactable con cuerpo sólido, va en World/Entities). Se le asigna Decision.
  Ofrece una sola vez y queda gris.
- EventBus: decision_requested(decision) abre el panel; decision_resolved(decision, chosen) es para logs y finales.
- DecisionPanel (estado DIALOG): W/S o flechas para elegir, E para confirmar, o ratón. Aplica los efectos
  una sola vez con Simulation.apply_change. Una opción que costaría más dinero del que tienes se desactiva.
- Depuración: Alt + 1/2/3 deja dinero/energía/tiempo en 1.

## Hostiles
- Datos: HostileDefinition (data/hostiles/): id, comportamiento (HostileConfig de P2), efecto del golpe, tick y color.
- Hostile (scenes/hostiles/hostile.tscn, en World/Entities): se mueve celda a celda (GridUtils.CELL_SIZE = 32 px),
  decide con HostileBrain (caminata + persecución) y golpea una sola vez por escenario al tocar el Hurtbox del jugador.
- Una celda está libre si una consulta de física no choca con world ni decoration (paredes, LevelBounds, muebles).
- Un hostil queda inmóvil fuera del estado PLAYING (diálogo, pausa, transiciones).
- Player: grupo "player", hijo Hurtbox y animación hurt al recibir un golpe.
- EventBus.hostile_hit(definition) es para logs y finales.
- Daño por defecto (Guía): -5 energía y -2 tiempo. Los hostiles de dinero (H-I3, H-V3) quitan -2 de dinero.

## Colas, descanso y objetos
- Fila (modelo 1): una DecisionOption con queue (QueueConfig). El botón muestra "N en la fila, espera estimada W de tiempo"
  (Lq y Wq de QueueModel). La espera real se sortea al elegir (Simulation.queue_wait) y se avisa con una notificación.
- Punto de fila: un Npc (scenes/npcs/npc.tscn) con una Decision de fila y su Action Text. QueueCrowd dibuja la gente (Lq).
- Descanso (modelo 5): RestSpot (scenes/objects/rest_spot.tscn) pone Player.is_resting. PlayerSimulationBridge reporta REST;
  moverse o un golpe lo levanta, y termina solo cerca de la energía máxima.
- Objetos: ItemDefinition (data/items/) + ItemPickup (scenes/objects/item_pickup.tscn), de un solo uso.
  Un objeto que cuesta dinero no se puede tomar si no alcanza (StatsManager.can_afford).
- Las filas de las ventanillas (A corta y lenta, B larga y rápida) son dos QueueConfig en data/simulation/.

## El Marcador (Work 3)
- ClockChallengeLevel (hereda de BaseLevel) en work_03; parámetros en data/challenges/el_marcador.tres.
- Reloj propio de 45 s, pausado en diálogos/pausa/transiciones. El stat Tiempo baja time_cost (6) en toda la duración:
  Simulation.set_time_cost_over(). La energía usa Travel Distance = 1500.
- 3 carpetas sorteadas (Monte Carlo) entre los Marker2D de FolderSpawns. Una carpeta es un ItemPickup sin efectos.
- Un golpe resta hit_penalty_seconds (3 s); una espera de la fila resta espera x wait_seconds_per_unit (3 s).
- Entregar = resolver la decisión queue_delivery con las 3 carpetas: bono +10 y salida abierta. Fallo = D-05.
- SceneManager.defeat_reason_override pone el texto D-05 mientras dura el encuentro (el paso 12 lo reemplaza).
- EventBus: challenge_clock_changed, challenge_progress_changed, challenge_finished(is_success, seconds_left), queue_waited.
- work_03: 960x544, muro con dos huecos (corto con más hostiles, largo con menos).
