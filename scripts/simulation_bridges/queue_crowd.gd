class_name QueueCrowd
extends Node2D
## The line of people at a queue on the map (model 1, M/M/1), always moving:
## - Starts with n people drawn from the stationary distribution P(n) = (1 - ρ) ρ^n.
## - People arrive with exponential gaps (rate λ) and join the end of the line.
## - The person at the front (this node's position) is served for an exponential time (rate μ)
##   and leaves; everybody steps forward.
## Joining it opens QueueScreen with the same people; when the player leaves, set_people() leaves
## the line as it ended. One model time unit lasts seconds_per_unit real seconds.

const GROUP: StringName = &"queue_crowds"
const PERSON_SIZE: Vector2 = Vector2(32.0, 48.0)
const CROWD_DEFINITIONS: Array[HostileDefinition] = [
	preload("res://data/hostiles/h_crowd_a.tres"),
	preload("res://data/hostiles/h_crowd_b.tres"),
	preload("res://data/hostiles/h_crowd_c.tres"),
]
const MAX_PEOPLE: int = 9
const STEP_SPEED: float = 90.0  # px/s people walk when the line moves.
const LEAVE_DISTANCE: float = 60.0

@export var queue: QueueConfig
## Direction in which the line grows (any non-zero vector).
@export var direction: Vector2 = Vector2.LEFT
## Distance in pixels between consecutive people.
@export_range(8.0, 96.0, 1.0, "suffix:px") var spacing: float = 36.0
## Direction the people face.
@export var facing_direction: Vector2 = Vector2.RIGHT
## Real seconds per model time unit (λ and μ are per unit).
@export_range(0.1, 5.0, 0.1, "suffix:s") var seconds_per_unit: float = 1.0

## Index 0 is being served.
var _line: Array[Node2D] = []
var _next_arrival: float = 0.0
var _service_left: float = 0.0
var _arrivals: int = 0
var _served: int = 0
var _rng: Lcg


func _ready() -> void:
	assert(queue != null, "%s: queue is not assigned." % name)
	assert(direction != Vector2.ZERO, "%s: queue direction cannot be zero." % name)
	assert(queue.arrival_rate < queue.service_rate, "%s: λ must be lower than μ." % name)
	add_to_group(GROUP)
	_rng = Simulation.rng
	# Steady state: P(n) = (1 - ρ) ρ^n, drawn by inverse transform of the geometric distribution.
	var rho: float = QueueModel.utilization(queue)
	var people: int = 0
	while _rng.next() < rho and people < MAX_PEOPLE - 1:
		people += 1
	for i: int in people:
		_add_person(true)
	_next_arrival = _rng.exponential(queue.arrival_rate)
	_service_left = _rng.exponential(queue.service_rate)


func _process(delta: float) -> void:
	# Only while playing: the line freezes during dialogs, so the number the player reads in the
	# decision panel is the number QueueScreen starts with.
	if GameManager.current_state != GameState.Type.PLAYING or SceneManager.is_transitioning():
		return
	var dt: float = delta / seconds_per_unit
	_next_arrival -= dt
	if _next_arrival <= 0.0:
		_next_arrival = _rng.exponential(queue.arrival_rate)
		if _line.size() < MAX_PEOPLE:
			_add_person(false)
	if not _line.is_empty():
		_service_left -= dt
		if _service_left <= 0.0:
			_serve_front()
	_move_people(delta)


## Leaves [param count] people in line (after the player's turn in QueueScreen).
func set_people(count: int) -> void:
	count = clampi(count, 0, MAX_PEOPLE)
	while _line.size() > count:
		_line.pop_back().queue_free()
	while _line.size() < count:
		_add_person(false)


## People in line right now (the one being served included).
func people_in_line() -> int:
	return _line.size()


func _add_person(placed: bool) -> void:
	var sprite: AnimatedSprite2D = _make_person(_line.size())
	add_child(sprite)
	var slot: Vector2 = _slot(_line.size())
	# New arrivals walk in from a bit further back; the initial line is already in place.
	sprite.position = slot if placed else slot + direction.normalized() * spacing * 2.0
	_line.append(sprite)
	if not placed:
		_arrivals += 1


func _serve_front() -> void:
	var sprite: Node2D = _line.pop_front()
	_served += 1
	_service_left = _rng.exponential(queue.service_rate)
	var away: Vector2 = -direction.normalized().orthogonal() * LEAVE_DISTANCE
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + away, 0.6)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.6)
	tween.tween_callback(sprite.queue_free)


func _move_people(delta: float) -> void:
	for i: int in _line.size():
		var node: Node2D = _line[i]
		node.global_position = node.global_position.move_toward(to_global(_slot(i)), STEP_SPEED * delta)


func _slot(index: int) -> Vector2:
	return direction.normalized() * spacing * index


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
