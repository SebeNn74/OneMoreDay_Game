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

## Autoloads (core/)
- EventBus: señales globales.
- StatsManager: money, energy y time (configurados en data/stats/*.tres).
- GameManager: estado general del juego.

## Capas de física 2D
1 world, 2 player, 3 interactables, 4 hostiles.
Los nombres están en Project Settings > Layer Names > 2D Physics.
