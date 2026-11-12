extends Node
## Autoload. Single entry point to the five simulation models (P2-09).
## Owns the day's random generator, so every model draws from the same reproducible stream,
## and applies every resource change through StatsManager.
##
## Usage from other systems:
##   Simulation.start_day()                          # at the start of each day
##   Simulation.queue_wait(queue_config)             # model 1: waits and charges TIME
##   RandomWalk.next_cell(cell, config, Simulation.rng, is_free)       # model 2
##   Simulation.draw_event(GameEvent.Stage.COMMUTE)  # model 3: then apply_event(event)
##   HostileBrain.new(config).next_cell(..., Simulation.rng, ...)      # model 4
##   Simulation.set_player_activity(ResourceDynamics.Activity.WALK)    # model 5, every frame
##   movement speed * Simulation.speed_factor()      # model 5 fatigue feedback
##   Simulation.begin_level(travel_distance)         # model 5: every level, when it loads

## Emitted every time a model affects the game. Evidence for testing and the gameplay video.
signal model_used(model: StringName, detail: String)

const MODEL_QUEUE: StringName = &"Colas M/M/1"
const MODEL_RANDOM_WALK: StringName = &"Caminata aleatoria"
const MODEL_MONTE_CARLO: StringName = &"Monte Carlo"
const MODEL_AGENTS: StringName = &"Basado en agentes"
const MODEL_DYNAMICS: StringName = &"Dinámica de sistemas"
## Seed used when start_day() gets none. -1 = different every day.
const DEFAULT_SEED: int = -1

const EVENT_CATALOG: EventCatalog = preload("res://data/events/event_catalog.tres")
const DYNAMICS_CONFIG: DynamicsConfig = preload("res://data/simulation/dynamics.tres")
const PLAYER_MOVEMENT: MovementConfig = preload("res://data/player/movement_config.tres")

var rng: Lcg
var dynamics: ResourceDynamics
var player_activity: ResourceDynamics.Activity = ResourceDynamics.Activity.IDLE

var _event_picker: EventPicker
# True when the player reported its activity during the last frame.
var _player_reporting: bool = false
## Level switch for the continuous flows.
var flows_enabled: bool = true
## Multiplier of the continuous flows in the current level.
var flow_scale: float = 1.0
# What the continuous flows spent in the current level (negative = recovered).
var _level_energy_spent: float = 0.0
var _level_time_spent: float = 0.0

func _ready() -> void:
	dynamics = ResourceDynamics.new(DYNAMICS_CONFIG, PLAYER_MOVEMENT.walk_speed)
	_event_picker = EventPicker.new(EVENT_CATALOG)
	start_day()


## Resets the generator and the event pools. Pass a fixed seed to replay a day exactly.
func start_day(seed_value: int = DEFAULT_SEED) -> void:
	if seed_value == DEFAULT_SEED:
		seed_value = Time.get_ticks_usec()
	rng = Lcg.new(seed_value)
	_event_picker.reset_day()
	print("[Simulation] Day seed: %d" % seed_value)


## Model 1. Samples the player's wait in [param config], charges it to TIME and returns it.
func queue_wait(config: QueueConfig) -> float:
	var wait: float = QueueModel.sample_player_wait(config, rng)
	StatsManager.modify(StatDefinition.Type.TIME, -wait)
	report(MODEL_QUEUE, "%s: espera %.2f (Wq teórico %.2f, ρ = %.2f)" % [
		config.display_name, wait, QueueModel.mean_wait(config), QueueModel.utilization(config)])
	return wait


## Model 3. Draws an event of [param stage] that has not happened today (null if none is left).
func draw_event(stage: GameEvent.Stage) -> GameEvent:
	var event: GameEvent = _event_picker.draw(stage, rng)
	if event != null:
		report(MODEL_MONTE_CARLO, "%s (peso %d)" % [event.id, event.weight])
	return event


## Applies the effects of an event to the stats.
func apply_event(event: GameEvent) -> void:
	apply_change(event.money, event.energy, event.time)


## Applies a pulse to the three stats (events, NPC options, hostile hits).
func apply_change(money: float, energy: float, time: float) -> void:
	StatsManager.modify(StatDefinition.Type.MONEY, money)
	StatsManager.modify(StatDefinition.Type.ENERGY, energy)
	StatsManager.modify(StatDefinition.Type.TIME, time)


## Model 5. The player reports what it is doing every frame.
func set_player_activity(activity: ResourceDynamics.Activity) -> void:
	player_activity = activity
	_player_reporting = true


## Model 5. Multiplier for the player's movement speed (fatigue feedback loop).
func speed_factor() -> float:
	return dynamics.speed_factor(StatsManager.get_value(StatDefinition.Type.ENERGY))


## Model 5. Called by every level when it loads.
func begin_level(travel_distance: float) -> void:
	assert(travel_distance > 0.0, "Simulation: travel_distance must be positive.")
	flow_scale = DYNAMICS_CONFIG.scenario_length / travel_distance
	_level_energy_spent = 0.0
	_level_time_spent = 0.0
	print("[Simulation] Level path: %.0f px, flow scale x%.2f" % [travel_distance, flow_scale])


## Model 5. Called when the player reaches the exit. Reports what the flows cost in the level.
func end_level(level_name: String) -> void:
	if not flows_enabled:
		return
	report(MODEL_DYNAMICS, "%s: el trayecto costó %.1f de energía y %.1f de tiempo" % [
		level_name, _level_energy_spent, _level_time_spent])


## Model 5. Euler integration of the continuous flows, one step per physics frame.
## Runs only in frames where the player reported its activity.
func _physics_process(delta: float) -> void:
	var player_reported: bool = _player_reporting
	_player_reporting = false  # The player must report again every frame.
	if not player_reported or not flows_enabled or GameManager.current_state != GameState.Type.PLAYING:
		return
	var step: float = delta * flow_scale
	var energy: float = StatsManager.get_value(StatDefinition.Type.ENERGY)
	var max_energy: float = StatsManager.get_definition(StatDefinition.Type.ENERGY).max_value
	var energy_change: float = dynamics.energy_rate(energy, max_energy, player_activity) * step
	var time_change: float = dynamics.time_rate() * step
	StatsManager.modify(StatDefinition.Type.ENERGY, energy_change)
	StatsManager.modify(StatDefinition.Type.TIME, time_change)
	_level_energy_spent -= energy_change
	_level_time_spent -= time_change
	if energy >= DYNAMICS_CONFIG.fatigue_threshold and StatsManager.get_value(StatDefinition.Type.ENERGY) < DYNAMICS_CONFIG.fatigue_threshold:
		report(MODEL_DYNAMICS, "Energía bajo %.0f: el personaje se cansa y camina más lento" % DYNAMICS_CONFIG.fatigue_threshold)


## Logs that a model affected the game and emits model_used. Hostile and walker scripts call it
## with MODEL_RANDOM_WALK or MODEL_AGENTS when something observable happens (e.g. a chase starts).
func report(model: StringName, detail: String) -> void:
	print("[Simulation] %s | %s" % [model, detail])
	model_used.emit(model, detail)
