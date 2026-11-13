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
