extends SceneTree
## Headless self-test of the simulation port (P2-08). Every expected value was produced by the
## Python models in simulation_standalone/ with seed 12345, so passing proves that the game runs
## the same models that were validated against theory.
## Run from the project folder:
##   godot --headless --import
##   godot --headless --path . -s res://tools/simulation_self_test.gd

const SEED: int = 12345
const TOLERANCE: float = 1e-9

const LCG_FIRST: Array[float] = [0.0204, 0.01654, 0.54315, 0.6349, 0.91002]
const QUEUE_SAMPLES: int = 20000
const QUEUE_MEAN_WAIT: float = 4.029255170510533
const EVENT_IDS: Array[String] = ["EV-06", "EV-07", "EV-10", "EV-16", "EV-18", "EV-12", "EV-14"]
const WALK_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 0),
]
const CHASER_CELLS: Array[Vector2i] = [
	Vector2i(6, 5), Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 5),
	Vector2i(4, 5), Vector2i(3, 5), Vector2i(3, 5), Vector2i(3, 5),
]
const CHASER_STATES: Array[HostileBrain.State] = [
	HostileBrain.State.PATROL, HostileBrain.State.CHASE, HostileBrain.State.CHASE, HostileBrain.State.CHASE,
	HostileBrain.State.CHASE, HostileBrain.State.CHASE, HostileBrain.State.CHASE, HostileBrain.State.CHASE,
]
# Python model 5: (seconds, energy spent, time spent) walking across one scenario at dt = 1/60.
const CROSSINGS: Dictionary = {100.0: [4.266666666666657, 5.0, 6.0], 25.0: [5.949999999999984, 6.97265625, 8.3671875]}
const DRAIN: float = 1.171875
const CLOCK: float = 1.40625
const CRITICAL_ENERGY: float = 17.320508075688775

# Grids of the Python models 2 (platform) and 4 (street).
const PLATFORM_SIZE: Vector2i = Vector2i(12, 6)
const PLATFORM_BLOCKED: Array[Vector2i] = [
	Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 2), Vector2i(4, 3), Vector2i(8, 1), Vector2i(8, 4), Vector2i(10, 2),
]
const STREET_SIZE: Vector2i = Vector2i(20, 10)
const STREET_BLOCKED: Array[Vector2i] = [
	Vector2i(5, 3), Vector2i(5, 4), Vector2i(6, 3), Vector2i(6, 4), Vector2i(10, 7), Vector2i(11, 7),
	Vector2i(12, 7), Vector2i(14, 2), Vector2i(15, 2), Vector2i(9, 1), Vector2i(17, 5),
]

var _failures: int = 0


func _initialize() -> void:
	print("Simulation self-test (references: Python models, seed %d)" % SEED)
	_test_lcg()
	_test_queue()
	_test_random_walk()
	_test_events()
	_test_hostile()
	_test_dynamics()
	print("RESULT: %s" % ("all checks passed" if _failures == 0 else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _test_lcg() -> void:
	var rng: Lcg = Lcg.new(SEED)
	var values: Array[float] = []
	for i: int in LCG_FIRST.size():
		values.append(rng.next())
	_check("LCG: first numbers equal Python", values == LCG_FIRST, str(values))


func _test_queue() -> void:
	var config: QueueConfig = load("res://data/simulation/queue_bus_stop.tres")
	var rng: Lcg = Lcg.new(SEED)
	var total: float = 0.0
	for i: int in QUEUE_SAMPLES:
		total += QueueModel.sample_player_wait(config, rng)
	var mean: float = total / QUEUE_SAMPLES
	_check("Colas: mean player wait equals Python", absf(mean - QUEUE_MEAN_WAIT) < TOLERANCE, str(mean))
	_check("Colas: theoretical Wq = 4", is_equal_approx(QueueModel.mean_wait(config), 4.0),
		str(QueueModel.mean_wait(config)))


func _test_random_walk() -> void:
	var config: RandomWalkConfig = load("res://data/simulation/walk_symmetric.tres")
	var rng: Lcg = Lcg.new(SEED)
	var is_free: Callable = _grid_checker(PLATFORM_SIZE, PLATFORM_BLOCKED)
	var cell: Vector2i = Vector2i.ZERO
	var cells: Array[Vector2i] = []
	for i: int in WALK_CELLS.size():
		cell = RandomWalk.next_cell(cell, config, rng, is_free)
		cells.append(cell)
	_check("Caminata: cells equal Python", cells == WALK_CELLS, str(cells))


func _test_events() -> void:
	var picker: EventPicker = EventPicker.new(load("res://data/events/event_catalog.tres"))
	var rng: Lcg = Lcg.new(SEED)
	var ids: Array[String] = []
	for i: int in 3:
		ids.append(picker.draw(GameEvent.Stage.COMMUTE, rng).id)
	for i: int in 4:
		ids.append(picker.draw(GameEvent.Stage.WORK, rng).id)
	_check("Monte Carlo: drawn events equal Python", ids == EVENT_IDS, str(ids))
	var commute_left: int = 0
	while picker.draw(GameEvent.Stage.COMMUTE, rng) != null:
		commute_left += 1
	_check("Monte Carlo: no repetition (3 of 6 commute events left)", commute_left == 3, str(commute_left))


func _test_hostile() -> void:
	var config: HostileConfig = load("res://data/simulation/hostile_chaser.tres").duplicate()
	config.vision_radius = 3
	var brain: HostileBrain = HostileBrain.new(config)
	var rng: Lcg = Lcg.new(SEED)
	var is_free: Callable = _grid_checker(STREET_SIZE, STREET_BLOCKED)
	var cell: Vector2i = Vector2i(6, 6)
	var cells: Array[Vector2i] = []
	var states: Array[HostileBrain.State] = []
	for i: int in CHASER_CELLS.size():
		cell = brain.next_cell(cell, Vector2i(3, 5), rng, is_free)
		cells.append(cell)
		states.append(brain.state)
	_check("Agentes: chaser cells equal Python", cells == CHASER_CELLS, str(cells))
	_check("Agentes: chaser states equal Python", states == CHASER_STATES, str(states))
	_check("Agentes: first contact is a hit", brain.register_contact(), "")
	_check("Agentes: cooldown ignores later contacts", not brain.register_contact(), "")


func _test_dynamics() -> void:
	var movement: MovementConfig = load("res://data/player/movement_config.tres")
	var dynamics: ResourceDynamics = ResourceDynamics.new(load("res://data/simulation/dynamics.tres"), movement.walk_speed)
	_check("Dinámica: calibrated k and c equal Python",
		absf(dynamics.drain - DRAIN) < TOLERANCE and absf(dynamics.clock - CLOCK) < TOLERANCE,
		"%f %f" % [dynamics.drain, dynamics.clock])
	_check("Dinámica: critical energy E* equals Python", absf(dynamics.critical_energy() - CRITICAL_ENERGY) < TOLERANCE,
		str(dynamics.critical_energy()))
	var dt: float = 1.0 / 60.0
	for start_energy: float in CROSSINGS:
		var energy: float = start_energy
		var time: float = 100.0
		var progress: float = 0.0
		var seconds: float = 0.0
		while progress < dynamics.config.scenario_length and energy > 0.0:
			var speed: float = movement.walk_speed * dynamics.speed_factor(energy)
			energy = clampf(energy + dynamics.energy_rate(energy, 100.0, ResourceDynamics.Activity.WALK) * dt, 0.0, 100.0)
			time += dynamics.time_rate() * dt
			progress += speed * dt
			seconds += dt
		var expected: Array = CROSSINGS[start_energy]
		var matches: bool = (absf(seconds - expected[0]) < TOLERANCE and absf(start_energy - energy - expected[1]) < TOLERANCE
			and absf(100.0 - time - expected[2]) < TOLERANCE)
		_check("Dinámica: crossing from E = %d equals Python" % start_energy, matches,
			"%f s, %f E, %f T" % [seconds, start_energy - energy, 100.0 - time])


func _grid_checker(size: Vector2i, blocked: Array[Vector2i]) -> Callable:
	return func(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y and cell not in blocked


func _check(name: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("  [%s] %s %s" % ["OK" if passed else "FAIL", name, "" if passed else "-> got " + detail])
