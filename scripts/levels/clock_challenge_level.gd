class_name ClockChallengeLevel
extends BaseLevel
## El Marcador: collect the folders scattered around the office and deliver
## them before the clock reaches 0. No combat: the player moves, dodges and decides.
##  - Folders appear in positions drawn (Monte Carlo) from the Marker2D children of FolderSpawns.
##  - A hostile hit and a queue wait take seconds off the clock.
##  - The delivery point unlocks with all the folders. Delivering on time gives a bonus and
##    unlocks the exit. Clock at 0 (or any stat depleted meanwhile) is ending D-05.
## The TIME stat costs config.time_cost over the whole duration, so the encounter is budgeted
## like any other level.

const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/objects/item_pickup.tscn")

@export var config: ClockChallengeConfig
## Message shown when the player touches the locked exit (player-visible, Spanish).
@export_multiline var blocked_exit_hint: String = ""

@onready var _folder_spawns: Node2D = %FolderSpawns
@onready var _delivery_point: Npc = %DeliveryPoint
@onready var _interactables: Node2D = $World/Interactables

var _seconds_left: float = 0.0
var _folders_collected: int = 0
var _is_clock_running: bool = false
var _is_finished: bool = false


func _ready() -> void:
	super()
	assert(config != null, "%s: config is not assigned." % name)
	_seconds_left = config.duration_seconds
	_exit_zone.locked = true
	_exit_zone.blocked_entered.connect(_on_exit_blocked)
	_delivery_point.enabled = false  # Unlocks with all the folders.
	Simulation.set_time_cost_over(config.time_cost, config.duration_seconds)
	_spawn_folders()

	EventBus.item_used.connect(_on_item_used)
	EventBus.hostile_hit.connect(_on_hostile_hit)
	EventBus.queue_waited.connect(_on_queue_waited)
	EventBus.decision_resolved.connect(_on_decision_resolved)
	EventBus.challenge_progress_changed.emit(_folders_collected, config.folder_count)
	EventBus.challenge_clock_changed.emit(_seconds_left)
	EventBus.challenge_started.emit()

	if SceneManager.is_transitioning():
		# The level loads behind the fade: wait until it ends to show the intro.
		EventBus.day_step_started.connect(_show_intro.unbind(1), CONNECT_ONE_SHOT)
	else:
		_show_intro()


func _physics_process(delta: float) -> void:
	if not _is_clock_running or GameManager.current_state != GameState.Type.PLAYING or SceneManager.is_transitioning():
		return
	_change_clock(-delta)
	_check_deadline()


## Model 3 (Monte Carlo): draws the folder positions, without repetition, from the spawn markers.
func _spawn_folders() -> void:
	var candidates: Array[Node] = _folder_spawns.get_children()
	assert(candidates.size() >= config.folder_count, "%s: FolderSpawns needs at least %d markers." % [
		name, config.folder_count])
	var chosen: PackedStringArray = []
	for _i: int in config.folder_count:
		var picked: Marker2D = candidates.pop_at(Simulation.rng.index(candidates.size())) as Marker2D
		_spawn_folder(picked.global_position)
		chosen.append(str(picked.name))
	Simulation.report(Simulation.MODEL_MONTE_CARLO, "%s: carpetas sorteadas en %s" % [
		config.display_name, ", ".join(chosen)])


func _spawn_folder(world_position: Vector2) -> void:
	var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate() as ItemPickup
	pickup.item = config.folder_item  # Before add_child: the pickup reads it in _ready().
	_interactables.add_child(pickup)
	pickup.global_position = world_position


func _show_intro() -> void:
	EventBus.notification_closed.connect(_start_clock, CONNECT_ONE_SHOT)
	EventBus.notification_requested.emit(config.intro_text)


func _start_clock() -> void:
	_is_clock_running = true


func _change_clock(seconds: float) -> void:
	_seconds_left = maxf(_seconds_left + seconds, 0.0)
	EventBus.challenge_clock_changed.emit(_seconds_left)


func _check_deadline() -> void:
	if _seconds_left <= 0.0:
		_fail()


func _on_item_used(item: ItemDefinition) -> void:
	if _is_finished or item != config.folder_item:
		return
	_folders_collected += 1
	EventBus.challenge_progress_changed.emit(_folders_collected, config.folder_count)
	if _folders_collected >= config.folder_count:
		_delivery_point.enabled = true


func _on_hostile_hit(_definition: HostileDefinition) -> void:
	if not _is_clock_running or _is_finished:
		return
	_change_clock(-config.hit_penalty_seconds)
	_check_deadline()


## Model 1 meets the clock: the wait at the delivery point is time the clock does not give back.
## It is judged in _on_decision_resolved(), once the player has chosen.
func _on_queue_waited(_queue: QueueConfig, wait: float) -> void:
	if not _is_clock_running or _is_finished:
		return
	_change_clock(-wait * config.wait_seconds_per_unit)


func _on_decision_resolved(decision: DecisionDefinition, _chosen: DecisionOption) -> void:
	if _is_finished or decision != config.delivery_decision:
		return
	if _seconds_left <= 0.0:
		_fail()
	else:
		_succeed()


func _succeed() -> void:
	_is_finished = true
	_is_clock_running = false
	Simulation.apply_change(config.bonus_money, 0.0, 0.0)
	_exit_zone.locked = false
	EventBus.challenge_finished.emit(true, _seconds_left)
	Simulation.report(Simulation.MODEL_DYNAMICS, "%s: entregaste con %.1f s de sobra (bono %+.0f)" % [
		config.display_name, _seconds_left, config.bonus_money])


## Ending D-05: EndingResolver picks it from what RunLog recorded (clock failure or energy at 0).
func _fail() -> void:
	if _is_finished:
		return
	_is_finished = true
	_is_clock_running = false
	EventBus.challenge_finished.emit(false, 0.0)
	SceneManager.finish_day(false)


func _on_exit_blocked() -> void:
	if not blocked_exit_hint.is_empty():
		EventBus.notification_requested.emit(blocked_exit_hint)
