# ONE MORE DAY - GAME

Roguelike 2D top-down en pixel art. Motor: Godot 4.x (GDScript).

## Cómo ejecutar
Requisito: [Godot 4.7](https://godotengine.org/download) (versión estándar, no .NET). El proyecto usa el renderer
GL Compatibility, así que corre en casi cualquier PC.

**Desde el editor**
1. Abrir Godot > Importar > seleccionar `project.godot` de esta carpeta > Importar y editar.
   La primera vez tarda unos segundos importando los recursos.
2. F5 (o el botón ▶ arriba a la derecha) arranca el juego desde el menú principal.
   F6 corre solo la escena abierta (útil para probar un nivel o un final con Preview Ending Id).

**Desde la terminal** (cambiar `godot` por la ruta del ejecutable si no está en el PATH)

```
godot --path .
```

**Exportar un .exe (Windows)**
Editor > Proyecto > Exportar > Añadir > Windows Desktop > Exportar proyecto. La primera vez Godot pide descargar
las plantillas de exportación (Editor > Administrar plantillas de exportación > Descargar e instalar).

**Pruebas automáticas** (cada una imprime `RESULT: all checks passed`)

```
godot --headless --path . -s res://tools/simulation_self_test.gd
godot --headless --path . -s res://tools/ending_self_test.gd
godot --headless --path . -s res://tools/achievements_self_test.gd
godot --headless --path . -s res://tools/settings_self_test.gd
godot --headless --path . -s res://tools/bandit_walk_self_test.gd
godot --headless --path . -s res://tools/letter_queue_self_test.gd
```

**Módulo standalone del modelo 3 (Python 3.10+)**

```
pip install numpy scipy matplotlib
python simulation_standalone/jimenez_poveda_modelo3_montecarlo_mcmc.py
```

Guarda las tablas de validación y los gráficos en `simulation_standalone/salidas_modelo3/`.

Los logros y las opciones se guardan en `%APPDATA%\Godot\app_userdata\One More Day\` (borrar `achievements.cfg`
reinicia los logros).

## Resolución
Interna 640x360, ventana 1280x720, filtro de textura Nearest. Stretch "canvas_items" (escala entera): el arte se
ve igual (x2, Nearest), pero el texto se dibuja a la resolución de la ventana, así la letra pequeña es legible.
La fuente PixelOperator se importa con antialiasing en escala de grises por la misma razón.

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
EventBus, StatsManager, GameManager, Simulation, SceneManager, RunLog, Settings, AudioManager, Achievements.

## Capas de física 2D
1 world, 2 player, 3 npc, 4 enemy, 5 interactable, 6 decoration,
7 hitbox, 8 hurtbox, 9 detection, 10 projectile.
Constantes en scripts/utils/physics_layers.gd. Los nombres están en
Project Settings > Layer Names > 2D Physics.

## Flujo del día
- El orden de escenas se define en data/levels/day_sequence.tres (DaySequence).
- SceneManager (Autoload): start_day(), finish_day(victory), get_current_step().
- Cada nivel emite EventBus.level_completed desde su ExitZone.
- Una opción de decisión con `next_scene` (DecisionOption) sale del nivel sin pasar por la ExitZone: SceneManager.jump_to() salta a ese paso si ya está en el día (taxi -> commute_03) o lo juega en lugar del siguiente (bus -> commute_02_bus).
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

## Controles
| Acción | Tecla |
|---|---|
| Moverse | WASD / flechas |
| Interactuar / confirmar | E / Espacio |
| Correr | Shift |
| Pausa | Esc / P |
| Panel de modelos (mostrar/ocultar) | M (acción toggle_models, se puede reasignar) |
| Pantalla completa | F11 |
| Barra de depuración (solo en el editor) | F3 |

Mando: cruceta o stick izquierdo para moverse, A interactuar, RB correr, Start pausa.

## Opciones
- OptionsMenu (scripts/ui/options_menu.gd, se arma en código) se abre desde el menú principal y la pausa:
  volumen de música y efectos, pantalla completa y reasignación de teclas (clic en la tecla y pulsar otra;
  Esc cancela). Esc o la tecla de pausa cierran la pantalla.
- Settings (Autoload, core/settings.gd) guarda todo en user://settings.cfg al cerrar Opciones y lo aplica al arrancar.
  Crea los buses de audio Music y SFX (AudioManager toca por ellos) y agrega los eventos del mando.
- Reasignar cambia la tecla principal (la primera del Input Map); flechas, Espacio y P siguen como alternas. Si la tecla
  ya era la principal de otra acción, se intercambian; si era alterna de otra, se le quita. "Restaurar teclas" vuelve
  a project.godot.
- Los textos que nombran teclas usan Settings.key_name(acción) o Settings.with_keys("[{interact}] Seguir")
  (tokens {up} {down} {left} {right} {interact} {run} {pause}); no escribir "[E]" a mano.
- Prueba: godot --headless --path . -s res://tools/settings_self_test.gd

El panel de modelos (scripts/ui/model_feed.gd, en base_level) tiene una fila por modelo: se ilumina
cuando el modelo actúa (Simulation.model_used) y guarda lo último que hizo durante el día. La fila de
dinámica muestra en vivo los flujos de energía y tiempo por segundo y el factor de velocidad.

## Guía al jugador
- BaseLevel.required_npc: la salida queda cerrada hasta decidir con ese NPC (paraderos, conductor del bus,
  compañero, supervisora, vecina); la flecha apunta al NPC y tocar la salida avisa con quién hablar.
- LevelGuide (scripts/ui/level_guide.gd, en base_level): tarjeta "Cómo jugar" la primera vez que empieza un día
  en la sesión; al entrar a cada nivel, un aviso con la etapa y BaseLevel.objective (texto por escena); y una flecha
  amarilla hacia BaseLevel.get_guide_target() (la salida; la casa apunta al celular y El Marcador a la carpeta más
  cercana o al punto de entrega mientras la salida está cerrada).
- Los objetos muestran su efecto antes de tomarlos: "[E] Tomar un tinto (+10 energía, -$2.000)".

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
  Ofrece una sola vez y queda gris. Mientras se puede hablar con él tiene un círculo bajo los pies: amarillo, o morado
  si is_special (Abelardo y el jefe de la carta a García).
- EventBus: decision_requested(decision) abre el panel; decision_resolved(decision, chosen) es para logs y finales.
- DecisionPanel (estado DIALOG): W/S o flechas para elegir, E para confirmar, o ratón. Aplica los efectos
  una sola vez con Simulation.apply_change. Una opción que costaría más dinero del que tienes se desactiva.
- Depuración: Alt + 1/2/3 deja dinero/energía/tiempo en 1.
- Riesgo (modelo 3): DecisionOption.risk_chance, risk_text y risk_money/energy/time. La tarjeta muestra
  "Riesgo 30 %: ..." y al elegir se saca U del LCG del día: si U < p pasa lo malo. Un aviso dice qué salió
  (U contra p) y el panel de modelos lo registra como Monte Carlo. EventBus.risk_drawn es para RunLog.
- Bonificación por estado: bonus_stat, bonus_below, bonus_text y bonus_money/energy/time. Se aplica si al elegir
  ese recurso está por debajo del umbral (la tarjeta lo muestra en verde cuando se cumple).
- Estos campos (y minigame, queue, next_scene) se editan en el Inspector: tools/generate_decision_definitions.gd
  no los conoce y los borraría.
- Fila de la impresora (work_01): Npc invisible "Impresora" con data/decisions/queue_printer.tres y su QueueCrowd.

## Hostiles
- Datos: HostileDefinition (data/hostiles/): id, comportamiento (HostileConfig de P2), efecto del golpe, tick y color.
- Hostile (scenes/hostiles/hostile.tscn, en World/Entities): se mueve celda a celda (GridUtils.CELL_SIZE = 32 px)
  y decide con HostileBrain (caminata + persecución). Tras golpear espera hit_cooldown_seconds y puede volver a golpear.
- Una celda está libre si una consulta de física del tamaño del cuerpo no choca con world ni decoration y el sprite
  queda dentro del nivel (los hostiles grandes no se montan en paredes ni salen del mapa).
- Persiguen (HostileConfig.chases): visión de 4 casillas, avanzan el 75 % de los turnos y renuncian 3 casillas
  más allá de la visión. Para escapar hay que correr (gasta más energía: modelo 5).
- Vehículos (HostileDefinition.drives_in_lane): van en línea recta por su calle y vuelven tras esperas exponenciales
  (llegadas de Poisson, λ = 1/mean_gap_seconds; se reporta como Monte Carlo). El carril se elige solo (el eje libre
  más largo desde donde se puso) o con Hostile.lane_direction.
- Un golpe empuja al jugador (knockback_strength), lo pinta de rojo y sacude la cámara. Después de un golpe el jugador
  queda 1,5 s sin poder recibir otro (parpadea), así dos hostiles no encadenan golpes.
- Un hostil queda inmóvil fuera del estado PLAYING (diálogo, pausa, transiciones).
- EventBus.hostile_hit(definition) es para logs y finales.

## Minijuegos (cada uno implementa un modelo)
- DecisionOption.minigame: escena (Minigame) que se juega al elegir la opción; su resultado suma o resta sobre el
  efecto de la opción. Con next_scene (bus, taxi) el cambio de nivel ocurre al terminar.
- Minigame (scripts/minigames/minigame.gd): instrucciones con el nombre del modelo, cuenta 3-2-1, juego con un
  recuadro que muestra el modelo en vivo (_model_text), resultado con lo que costó. El juego queda en DIALOG.
- Bus · "Cuida la billetera" (bus_pickpocket) — Basado en agentes: cada ladrón es un agente
  (observa → tantea → roba → huye) con audacia propia; intenta con probabilidad tasa·audacia·(1 − tu atención en su
  lado). Pillarlo lo asusta (y al otro lo vuelve cauto); robar lo envalentona. A/D manotazo; robo = -$1.000 (máx. 4).
- Taxi · "Esquiva el trancón" (taxi_traffic) — Caminata aleatoria: cada 0,8 s cada vehículo da un paso
  (izquierda 0,2 / derecha 0,2 / seguir 0,6) con direccional antes de cambiarse. A/D cambian de carril;
  choque = -3 tiempo y -$1.000 (máx. 4).
- Tinto · "Sirve el tinto" (tinto_timing) — Dinámica de sistemas: el nivel L es el acumulado del caudal q
  (dL/dt = q); mantener E abre la llave (q sube) y al soltar q decae con c = 4, así que sigue cayendo café.
  Tres pocillos a su raya; -3 a +6 energía.
- Compañero · "Ordena el informe" (report_sequence) — Cadena de Markov: cada tecla sale de la fila de la matriz de
  transición de la anterior; solo se ven 2 teclas, el resto se anticipa con la matriz en pantalla.
  +$1.000 por hoja (máx. 4), -1 energía por error (máx. 5).
- Abelardo · "Caza bandidos" (bandit_hunt) — Caminata aleatoria sesgada 2D: en el bus de ida (commute_02_bus, NPC-08,
  sprite y retrato de tools/art/generate_abelardo.py) te asomas a su cabeza. Cada 0,35 s cada bandido da un paso:
  derecha 0,5 / izquierda 0,1 / arriba 0,2 / abajo 0,2; llegan con tiempos exponenciales (λ = 1,1/s). Cruzar 17
  casillas toma 17 / (0,5 − 0,1) = 42,5 pasos en promedio; el recuadro lo compara con los que escapan. Apuntar con el
  ratón o las teclas de mover, disparar con clic o interactuar. Da +2 energía y +1 tiempo, más +1 energía y +0,5 tiempo
  por captura (máx. 10). Prueba: godot --headless --path . -s res://tools/bandit_walk_self_test.gd
- Jefe de área · "La carta a García" (letter_garcia) — Colas M/M/1 con el jugador como servidor: en la esquina de la
  oficina 1 (work_01, NPC-09, sprite y retrato de tools/art/generate_boss_letter.py). Llegan cartas (Poisson, λ = 1,2/s)
  y se despachan al buzón de arriba (García), derecha (Gómez) o abajo (Díaz). μ̂ = despachadas / tiempo ocupado;
  con ρ = λ/μ̂ se muestran Lq = ρ²/(1 − ρ) y Wq = Lq/λ contra lo medido. Fila máxima 12 (las demás se desbordan).
  +$250 por carta bien despachada (máx. $4.000), +1 tiempo por carta a García (máx. 3), −0,5 energía por error
  (máx. −3). Prueba: godot --headless --path . -s res://tools/letter_queue_self_test.gd (cartero robot con μ = 2).
- Las opciones con minijuego muestran "(minijuego)" en su tarjeta (DecisionPanel).
- Empanadas · "Atrapa las empanadas" (empanada_catch) — Monte Carlo: los puntos de caída son muestras de una
  mezcla de dos normales (Box-Muller); el histograma de caídas estima la distribución. +1,5 energía por empanada (máx. 8).

## Colas, descanso y objetos
- Fila (modelo 1): QueueCrowd (scripts/simulation_bridges/queue_crowd.gd) es la fila del mapa: arranca con
  n ~ P(n) = (1 - ρ) ρ^n, llegan personas con tiempos exponenciales (λ) y el primero es atendido un tiempo exponencial
  (μ). Se congela durante los diálogos, así que el número del panel de decisión es el que se va a encontrar.
- QueueScreen corre a 2 s reales por minuto del modelo (SECONDS_PER_UNIT; mantener E lo acelera x4). Una barra sobre
  el servidor muestra la atención en curso y salen avisos "+1 llegó (λ)" y "atendido (μ)". Al llegar al frente
  también te atienden (servicio exponencial μ): el resultado muestra la espera en fila (Wq, lo que cuesta tiempo) y
  la atención (1/μ). Si no había fila lo explica con P(0) = 1 - ρ. El escenario es el paradero solo si la cola se
  llama "Paradero"; las demás (ventanillas, impresora) se dibujan como mostrador.
- Al elegir una opción con queue se abre QueueScreen (scripts/ui/queue_screen.gd): escena del paradero (bus al frente)
  o de la ventanilla, el jugador al final de la misma fila, panel con λ, μ, ρ, Lq y Wq teóricos y el estado en vivo
  (delante, detrás, minutos esperados) y la gráfica N(t) contra L = ρ/(1 - ρ). Mantener E adelanta el tiempo.
  La espera es el tiempo hasta llegar al frente (Simulation.record_queue_wait); al volver, la fila del mapa queda
  con la gente que llegó detrás.
- Punto de fila: un Npc (scenes/npcs/npc.tscn) con una Decision de fila; su QueueCrowd crece hacia `direction`.
- Descanso (modelo 5): RestSpot (scenes/objects/rest_spot.tscn) pone Player.is_resting. PlayerSimulationBridge reporta REST;
  moverse o un golpe lo levanta, y termina solo cerca de la energía máxima.
- Objetos: ItemDefinition (data/items/) + ItemPickup (scenes/objects/item_pickup.tscn), de un solo uso.
  Un objeto que cuesta dinero no se puede tomar si no alcanza (StatsManager.can_afford).
- Las filas de las ventanillas (A corta y lenta, B larga y rápida) son dos QueueConfig en data/simulation/.

## El Marcador (Work 3)
- ClockChallengeLevel (hereda de BaseLevel) en work_03; parámetros en data/challenges/el_marcador.tres.
- Reloj propio de 65 s (duration_seconds), pausado en diálogos/pausa/transiciones. Los hostiles del nivel caminan al
  70 % (hostile_speed_scale) y un golpe resta 2 s. El stat Tiempo baja time_cost (6) en toda la duración:
  Simulation.set_time_cost_over(). La energía usa Travel Distance = 1500.
- 3 carpetas sorteadas (Monte Carlo) entre los Marker2D de FolderSpawns. Una carpeta es un ItemPickup sin efectos.
- Un golpe resta hit_penalty_seconds (3 s); una espera de la fila resta espera x wait_seconds_per_unit (3 s).
- Entregar = resolver la decisión queue_delivery con las 3 carpetas: bono +10 y salida abierta. Fallo = D-05.
- SceneManager.defeat_reason_override pone el texto D-05 mientras dura el encuentro (el paso 12 lo reemplaza).
- EventBus: challenge_clock_changed, challenge_progress_changed, challenge_finished(is_success, seconds_left), queue_waited.
- work_03: 960x544, muro con dos huecos (corto con más hostiles, largo con menos).

## Dinero, vendedor y logros
- Vendedor ambulante (NPC-07, return_03, junto a la puerta de la casa): vende el "Gran Trancón VI" por $25.000, o
  regateando $18.000 con 50 % de riesgo de pagar completo. Comprarlo (RunLog.GAME_CHOICES) y llegar a casa da V-06.
- Una opción cuyo peor caso de riesgo dejaría el dinero en 0 se desactiva (DecisionPanel._is_affordable).
- V-05 (ahorro) pide $40.000 al llegar: más de los $30.000 con que se empieza.
- Achievements (Autoload, core/achievements.gd): un logro por final y tres más (Intocable: ganar sin golpes;
  Apostador: salir bien de 3 riesgos en un día; Coleccionista: todos los finales). Se guardan en
  user://achievements.cfg. Se desbloquean apenas se ganan: Apostador al tercer riesgo superado (EventBus.risk_drawn)
  y los de final en EventBus.day_finished (el final se decide con EndingResolver, igual que la pantalla final,
  al terminar ese frame: así un robo que deja el dinero en 0 ya quedó anotado y da D-04, no D-01).
  El aviso es un banner arriba al centro que entra con rebote; si son varios salen uno tras otro.
  Pantalla LOGROS en el menú principal (scripts/ui/achievements_menu.gd).
- Prueba: godot --headless --path . -s res://tools/achievements_self_test.gd (usa su propio archivo).

## Casa y recuerdo de victoria
- FlavorInteractable (scripts/interactables/flavor_interactable.gd): objeto que solo muestra textos (cama, nevera,
  escritorio, TV, calendario y fotos en home_01). Arma su propia forma y, si tiene texture, su sprite.
  El calendario y las fotos salen de tools/art/generate_home_extras.py.
- Victoria: DaySequence.victory_scene es scenes/end_screens/memory.tscn (hereda home_01 con MemoryLevel): luz cálida,
  textos de recuerdo, 25 s para caminar; al acabar o al salir por la puerta, SceneManager.show_ending().

## Transiciones y efectos
- SceneTransition.set_caption(): el negro entre niveles muestra "Un día más", "¡Tramo superado!", el cambio de etapa
  o el resultado del día (SceneManager, CAPTION_SECONDS).
- FatigueOverlay (scripts/ui/fatigue_overlay.gd, lo agrega BaseLevel si consume recursos): bajo el umbral de fatiga
  del modelo 5 la pantalla pierde color y se oscurecen los bordes.
- El jugador destella verde (buff) o morado (nerf) cuando un recurso cambia en 1 o más (no por los flujos).

## Audio
- Todo es CC0 de internet: assets/audio/CREDITS.md tiene la tabla de atribuciones (autor, archivo original, fuente).
- AudioManager: música por etapa, ambiente por BaseLevel.place (street, bus, office), jingles (inicio del día,
  tramo superado, victoria), sonido de buff/nerf, decisión buena o mala, alarma de El Marcador y timbre del celular.
- Música y efectos van por los buses Music y SFX (volumen en Opciones).
- Volumen nivelado: las pistas vienen de autores distintos (hasta 15 dB de diferencia). AudioManager.LOUDNESS_DB
  guarda lo medido con tools/measure_loudness.gd y cada pista suena como si midiera MUSIC_REFERENCE_DB. Los ambientes
  tienen su volumen en AMBIENCE_VOLUME_DB (la oficina: tecleo al frente y zumbido de fondo).

## Finales
- EndingResolver (pura) elige el final con las reglas de la pestaña 7: derrotas D-04, D-05, D-01, D-02, D-03;
  victorias V-06, V-03, V-04, V-05, V-01, V-02. Prueba: godot --headless --path . -s res://tools/ending_self_test.gd
- RunLog (Autoload, último de la lista) anota ayudas (V-03), El Marcador (V-04, D-05) y robos (D-04) y arma el RunSummary.
- EndingCatalog (data/endings/ending_catalog.tres) guarda los 11 finales y los umbrales. Se genera desde la tabla de
  tools/generate_ending_catalog.gd (sobrescribe el .tres): ahí se cambian textos, imágenes y umbrales.
- EndingScreen (scenes/end_screens/ending_screen.tscn) sirve para victoria y derrota. Muestra el resumen del día
  (recursos finales, decisiones, eventos, golpes y riesgos, de RunSummary) y botones para el ratón. El final se decide al abrirla.
  Con F6 y Preview Ending Id se ve cualquier final sin jugar.
- D-04: dinero a 0 justo después de EV-20 o del golpe de un hostil que quita dinero.
  D-05: el reloj del Marcador llega a 0, o la energía a 0 durante el encuentro.
