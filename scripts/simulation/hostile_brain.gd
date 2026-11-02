class_name HostileBrain
extends RefCounted
## Agent rules of a hostile. Port of update_hostile() and chase_step() in
## simulation_standalone/jimenez_poveda_modelo4_agentes.py.
## State machine: PATROL -> CHASE (player within vision) -> COOLDOWN (after hitting).
## A hostile hits at most once per scenario, as in the balance (tab 8).

signal state_changed(new_state: State)

enum State { PATROL, CHASE, COOLDOWN }

var config: HostileConfig
var state: State = State.PATROL


func _init(hostile_config: HostileConfig) -> void:
	assert(hostile_config.patrol != null, "HostileBrain: patrol config is not assigned.")
	config = hostile_config


## One tick: updates the state and returns the next cell. [param is_free] is Callable(Vector2i) -> bool.
func next_cell(cell: Vector2i, player_cell: Vector2i, rng: Lcg, is_free: Callable) -> Vector2i:
	if config.chases:
		var distance: int = _manhattan(cell, player_cell)
		if state == State.PATROL and distance <= config.vision_radius:
			_set_state(State.CHASE)
		elif state == State.CHASE and distance > config.vision_radius + config.lose_margin:
			_set_state(State.PATROL)
	if state == State.CHASE:
		if rng.next() < config.chase_probability:
			return _chase_step(cell, player_cell, is_free)
		return cell
	return RandomWalk.next_cell(cell, config.patrol, rng, is_free)


## True when this contact is a hit (first contact of the scenario); then the hostile cools down.
func register_contact() -> bool:
	if state == State.COOLDOWN:
		return false
	_set_state(State.COOLDOWN)
	return true


## Call at the start of each scenario.
func reset() -> void:
	_set_state(State.PATROL)


## Greedy move that shortens the distance, trying the longer axis first; stays if both are blocked.
func _chase_step(cell: Vector2i, target: Vector2i, is_free: Callable) -> Vector2i:
	var delta: Vector2i = target - cell
	var moves: Array[Vector2i] = [Vector2i(signi(delta.x), 0), Vector2i(0, signi(delta.y))]
	if absi(delta.y) > absi(delta.x):
		moves.reverse()
	for move: Vector2i in moves:
		if move != Vector2i.ZERO and is_free.call(cell + move):
			return cell + move
	return cell


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(new_state)


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
