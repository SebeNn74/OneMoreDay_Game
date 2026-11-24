class_name QueueCrowd
extends Node2D
## A live M/M/1 queue (model 1) that the player can see and join.
## - Starts with n people drawn from the stationary distribution P(n) = (1 - ρ) ρ^n.
## - People arrive with exponential gaps (rate λ) and join the end of the line.
## - The person at the front (this node's position) is served for an exponential time (rate μ)
##   and leaves; everybody steps forward.
## - serve_player() puts the player at the end; the wait is the time until they reach the front.
## One model time unit lasts seconds_per_unit real seconds. A sign above shows λ, μ, ρ and the line.

const GROUP: StringName = &"queue_crowds"
const PERSON_SIZE: Vector2 = Vector2(32.0, 48.0)
const CROWD_DEFINITIONS: Array[HostileDefinition] = [
	preload("res://data/hostiles/h_crowd_a.tres"),
	preload("res://data/hostiles/h_crowd_b.tres"),
	preload("res://data/hostiles/h_crowd_c.tres"),
]
const MAX_PEOPLE: int = 9
const STEP_SPEED: float = 90.0  # px/s people walk when the line moves.
## The player walks to their place in line faster, so joining does not feel slow.
const PLAYER_STEP_FACTOR: float = 3.0
const LEAVE_DISTANCE: float = 60.0
const SIGN_FORMAT: String = "%s: %d en fila
λ %.1f  μ %.1f  ρ %.2f"
const PLAYER_SIGN_FORMAT: String = "Delante de ti: %d  ·  esperando %.1f"

@export var queue: QueueConfig
## Direction in which the line grows (any non-zero vector).
@export var direction: Vector2 = Vector2.LEFT
## Distance in pixels between consecutive people.
@export_range(8.0, 96.0, 1.0, "suffix:px") var spacing: float = 36.0
## Direction the people face.
@export var facing_direction: Vector2 = Vector2.RIGHT
## Real seconds per model time unit (λ and μ are per unit).
@export_range(0.1, 5.0, 0.1, "suffix:s") var seconds_per_unit: float = 1.0

## Index 0 is being served. Each entry: {node: Node2D, is_player: bool}.
var _line: Array[Dictionary] = []
var _next_arrival: float = 0.0
var _service_left: float = 0.0
var _arrivals: int = 0
var _served: int = 0
var _player_wait: float = -1.0  # Units waited so far by the player; -1 = not in line.
var _player_done: bool = false
var _sign: Label
var _rng: Lcg


func _ready() -> void:
	assert(queue != null, "%s: queue is not assigned." % name)
	assert(direction != Vector2.ZERO, "%s: queue direction cannot be zero." % name)
	assert(queue.arrival_rate < queue.service_rate, "%s: λ must be lower than μ." % name)
	add_to_group(GROUP)
	_rng = Simulation.rng
	_sign = Label.new()
	_sign.add_theme_font_size_override("font_size", 12)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sign_style: StyleBoxFlat = StyleBoxFlat.new()
	sign_style.bg_color = Color(0.05, 0.08, 0.15, 0.8)
	sign_style.border_color = Color(0.45, 0.7, 1.0)  # The queue color of the model panel.
	sign_style.set_border_width_all(1)
	sign_style.set_corner_radius_all(3)
	sign_style.set_content_margin_all(3.0)
	_sign.add_theme_stylebox_override("normal", sign_style)
	_sign.z_index = 50
	add_child(_sign)
	# Steady state: P(n) = (1 - ρ) ρ^n, drawn by inverse transform of the geometric distribution.
	var rho: float = QueueModel.utilization(queue)
	var people: int = 0
	while _rng.next() < rho and people < MAX_PEOPLE - 1:
		people += 1
	for i: int in people:
		_add_person(false, true)
	_next_arrival = _rng.exponential(queue.arrival_rate)
	_service_left = _rng.exponential(queue.service_rate)
	_update_sign()


func _process(delta: float) -> void:
	var state: GameState.Type = GameManager.current_state
	if (state != GameState.Type.PLAYING and state != GameState.Type.DIALOG) or SceneManager.is_transitioning():
		return
	var dt: float = delta / seconds_per_unit
	_next_arrival -= dt
	if _next_arrival <= 0.0:
		_next_arrival = _rng.exponential(queue.arrival_rate)
		if _line.size() < MAX_PEOPLE:
			_add_person(false, false)
	if not _line.is_empty():
		if _line[0].is_player:
			_player_done = true  # The player reached the front: their turn.
		else:
			_service_left -= dt
			if _service_left <= 0.0:
				_serve_front()
	if _player_wait >= 0.0 and not _player_done:
		_player_wait += dt
	_move_people(delta)
	_update_sign()


## Puts [param player] at the end of the line and waits for their turn.
## Returns the wait in model units (0 if the line was empty). The game stays in DIALOG meanwhile.
func serve_player(player: Player) -> float:
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)
	_player_wait = 0.0
	_player_done = false
	var ahead: int = _line.size()
	_line.append({"node": player, "is_player": true})
	Simulation.report(Simulation.MODEL_QUEUE, "%s: te unes a la fila con %d delante (Wq teórico %.2f)" % [
		queue.display_name, ahead, QueueModel.mean_wait(queue)])
	while not _player_done:
		await Engine.get_main_loop().process_frame
		if not is_inside_tree():
			return _player_wait  # The level closed meanwhile (e.g. a stat ran out).
	var wait: float = _player_wait
	_player_wait = -1.0
	_player_done = false
	_line.pop_front()  # The player boards / is attended and leaves the line.
	_service_left = _rng.exponential(queue.service_rate)
	if GameManager.current_state == GameState.Type.DIALOG:
		GameManager.change_state(GameState.Type.PLAYING)
	return wait


## People in line right now (the one being served included).
func people_in_line() -> int:
	return _line.size()


func _add_person(is_player: bool, placed: bool) -> void:
	var sprite: AnimatedSprite2D = _make_person(_line.size())
	add_child(sprite)
	var slot: Vector2 = _slot(_line.size())
	# New arrivals walk in from a bit further back; the initial line is already in place.
	sprite.position = slot if placed else slot + direction.normalized() * spacing * 2.0
	_line.append({"node": sprite, "is_player": is_player})
	if not placed:
		_arrivals += 1


func _serve_front() -> void:
	var front: Dictionary = _line.pop_front()
	_served += 1
	_service_left = _rng.exponential(queue.service_rate)
	var sprite: Node2D = front.node
	var away: Vector2 = -direction.normalized().orthogonal() * LEAVE_DISTANCE
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + away, 0.6)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.6)
	tween.tween_callback(sprite.queue_free)


func _move_people(delta: float) -> void:
	for i: int in _line.size():
		var entry: Dictionary = _line[i]
		var target: Vector2 = to_global(_slot(i))
		var node: Node2D = entry.node
		var speed: float = STEP_SPEED * (PLAYER_STEP_FACTOR if entry.is_player else 1.0)
		node.global_position = node.global_position.move_toward(target, speed * delta)


func _slot(index: int) -> Vector2:
	return direction.normalized() * spacing * index


func _update_sign() -> void:
	var text: String = SIGN_FORMAT % [queue.display_name, _line.size(), queue.arrival_rate, queue.service_rate,
		QueueModel.utilization(queue)]
	if _player_wait >= 0.0:
		var ahead: int = 0
		for entry: Dictionary in _line:
			if entry.is_player:
				break
			ahead += 1
		text += "\n" + PLAYER_SIGN_FORMAT % [ahead, _player_wait]
	_sign.text = text
	_sign.reset_size()
	_sign.position = Vector2(-_sign.size.x / 2.0, -PERSON_SIZE.y - _sign.size.y - 4.0)


func _make_person(index: int) -> AnimatedSprite2D:
	var definition: HostileDefinition = CROWD_DEFINITIONS[(index + _arrivals) % CROWD_DEFINITIONS.size()]
	var direction_name: StringName = DirectionUtils.name_of(DirectionUtils.to_cardinal(facing_direction))
	var animation_name: StringName = StringName("%s_%s" % [definition.sprite_animation, direction_name])
	var frame: Texture2D = definition.sprite_frames.get_frame_texture(animation_name, 0)
	var frame_size: Vector2 = frame.get_size()
	var sprite_scale: float = minf(PERSON_SIZE.x / frame_size.x, PERSON_SIZE.y / frame_size.y)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = definition.sprite_frames
	sprite.animation = animation_name
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.offset = Vector2(0.0, -frame_size.y / 2.0)  # Origin at the feet.
	sprite.play(animation_name)
	return sprite
