class_name Hostile
extends Node2D
## A hostile agent. Moves cell by cell following HostileBrain, or, for vehicles
## (HostileDefinition.drives_in_lane), drives straight along its road and comes back after
## exponential gaps (Poisson arrivals).

const COOLDOWN_TINT: Color = Color(0.6, 0.6, 0.6)
## Square used to test whether a cell is free. Slightly smaller than a cell, so a wall that
## only touches the edge of the cell does not block it.
const CELL_PROBE_SIZE: float = GridUtils.CELL_SIZE - 4.0
const DEBUG_VISION_COLOR: Color = Color(1.0, 0.3, 0.3, 0.6)

@export var definition: HostileDefinition
## Vehicles only: direction of the lane. Zero picks the longer free axis at the start position.
@export var lane_direction: Vector2 = Vector2.ZERO

@onready var _hitbox: Area2D = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _alert: Label = $Alert

var _brain: HostileBrain
var _cell: Vector2i
var _target_position: Vector2
var _tick_elapsed: float = 0.0
var _player: Player
var _probe: RectangleShape2D
var _has_reported_walk: bool = false
var _cooldown_left: float = 0.0
## Level rectangle, so big sprites never stick out of the map. Empty when not inside a BaseLevel.
var _level_rect: Rect2
## Half the drawn sprite, used to keep it inside _level_rect.
var _sprite_half: Vector2
var _probe_offset: Vector2
var _lane_ready: bool = false
var _lane_from: Vector2
var _lane_to: Vector2
var _lane_heading: Vector2
var _lane_wait: float = 0.0


func _ready() -> void:
	assert(definition != null, "%s: definition is not assigned." % name)
	assert(definition.behavior != null, "%s: the definition has no behavior." % name)
	assert(definition.sprite_frames != null, "%s: the definition has no SpriteFrames." % name)
	var has_directional_animation: bool = false
	var has_all_directions: bool = true
	for direction: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var directional_animation: StringName = _directional_animation_name(direction)
		var direction_exists: bool = definition.sprite_frames.has_animation(directional_animation)
		has_directional_animation = has_directional_animation or direction_exists
		has_all_directions = has_all_directions and direction_exists
	assert(
		has_all_directions or (
			not has_directional_animation
			and definition.sprite_frames.has_animation(definition.sprite_animation)
		),
		"%s: SpriteFrames must contain either all four directional animations or the selected animation '%s'." % [
			name, definition.sprite_animation
		]
	)
	_hitbox.collision_layer = PhysicsLayers.HITBOX
	_hitbox.collision_mask = PhysicsLayers.HURTBOX
	_animated_sprite.sprite_frames = definition.sprite_frames
	var initial_animation: StringName = _animation_for_direction(Vector2.DOWN)
	var first_frame: Texture2D = definition.sprite_frames.get_frame_texture(initial_animation, 0)
	var frame_size: Vector2 = first_frame.get_size()
	var fit_scale: float = float(GridUtils.CELL_SIZE) / frame_size.x
	var sprite_scale: float = fit_scale * definition.sprite_scale
	_animated_sprite.scale = Vector2.ONE * sprite_scale
	_animated_sprite.position = Vector2(0.0, -frame_size.y * sprite_scale / 2.0)
	_animated_sprite.play(initial_animation)
	_sprite_half = frame_size * sprite_scale / 2.0
	var level: BaseLevel = owner as BaseLevel
	if level != null:
		_level_rect = Rect2(Vector2.ZERO, Vector2(level.level_size))

	var hitbox_shape := RectangleShape2D.new()
	hitbox_shape.size = definition.hitbox_size * definition.sprite_scale
	_hitbox_shape.shape = hitbox_shape
	_hitbox_shape.position = definition.hitbox_offset * definition.sprite_scale
	_alert.visible = false

	# The probe covers the whole body, so a big sprite (car, rain) cannot overlap walls.
	_probe = RectangleShape2D.new()
	_probe.size = Vector2(maxf(CELL_PROBE_SIZE, hitbox_shape.size.x), maxf(CELL_PROBE_SIZE, hitbox_shape.size.y))
	_probe_offset = _hitbox_shape.position if _probe.size.y > CELL_PROBE_SIZE else Vector2.ZERO
	_brain = HostileBrain.new(definition.behavior)
	_brain.state_changed.connect(_on_brain_state_changed)

	_cell = GridUtils.cell_of(global_position)
	_target_position = GridUtils.center_of(_cell)
	global_position = _target_position


func _physics_process(delta: float) -> void:
	if not _can_act():
		return
	if definition.drives_in_lane:
		_drive(delta)
		_update_cooldown(delta)
		if _animated_sprite.visible:
			_check_contact()
		return
	var step_speed: float = GridUtils.CELL_SIZE / definition.tick_seconds
	global_position = global_position.move_toward(_target_position, step_speed * delta)

	_tick_elapsed += delta
	if _tick_elapsed >= definition.tick_seconds:
		_tick_elapsed -= definition.tick_seconds
		_tick()
	_update_cooldown(delta)
	_check_contact()


## The brain stays in COOLDOWN until this timer ends; then it patrols (and can hit) again.
func _update_cooldown(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0:
		_brain.reset()


func _can_act() -> bool:
	return GameManager.current_state == GameState.Type.PLAYING and not SceneManager.is_transitioning()


func _tick() -> void:
	var player: Player = _find_player()
	if player == null:
		return
	var player_cell: Vector2i = GridUtils.cell_of(player.global_position)
	var destination: Vector2i = _brain.next_cell(_cell, player_cell, Simulation.rng, _is_cell_free)
	if destination == _cell:
		return
	var movement: Vector2i = destination - _cell
	_cell = destination
	_target_position = GridUtils.center_of(_cell)
	var animation_name: StringName = _animation_for_direction(Vector2(movement))
	if _animated_sprite.animation != animation_name:
		_animated_sprite.play(animation_name)
	_report_walk_once()


func _animation_for_direction(direction: Vector2) -> StringName:
	var directional_animation: StringName = _directional_animation_name(direction)
	if definition.sprite_frames.has_animation(directional_animation):
		return directional_animation
	return definition.sprite_animation


func _directional_animation_name(direction: Vector2) -> StringName:
	var cardinal: Vector2 = DirectionUtils.to_cardinal(direction)
	return StringName("%s_%s" % [definition.sprite_animation, DirectionUtils.name_of(cardinal)])


## A cell is free when no wall, bound or furniture overlaps it. Passed to the brain as a Callable.
func _is_cell_free(cell: Vector2i) -> bool:
	var center: Vector2 = GridUtils.center_of(cell)
	if _level_rect.has_area():
		var sprite_rect: Rect2 = Rect2(center - Vector2(_sprite_half.x, _sprite_half.y * 2.0), _sprite_half * 2.0)
		if not _level_rect.encloses(sprite_rect):
			return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _probe
	query.transform = Transform2D(0.0, center + _probe_offset)
	query.collision_mask = PhysicsLayers.ENEMY_BLOCKERS
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	return space.intersect_shape(query, 1).is_empty()


## Polled every frame (not area_entered) so a touch during a dialog is not lost.
func _check_contact() -> void:
	for area: Area2D in _hitbox.get_overlapping_areas():
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox != null and hurtbox.is_vulnerable() and _brain.register_contact():
			_hit(hurtbox)
			return


func _hit(hurtbox: Hurtbox) -> void:
	_cooldown_left = definition.hit_cooldown_seconds
	hurtbox.receive_hit(self)
	Simulation.apply_change(definition.hit_money, definition.hit_energy, definition.hit_time)
	EventBus.hostile_hit.emit(definition)
	Simulation.report(Simulation.MODEL_AGENTS, "%s golpea: E %+.0f, T %+.0f, $ %+.0f" % [
		definition.id, definition.hit_energy, definition.hit_time, definition.hit_money])


## Vehicles: drive to the end of the lane, vanish, wait an exponential gap, come back from the start.
func _drive(delta: float) -> void:
	if not _lane_ready:
		_setup_lane()
		return
	if _lane_wait > 0.0:
		_lane_wait -= delta
		if _lane_wait <= 0.0:
			global_position = _lane_from
			_animated_sprite.visible = true
			Simulation.report(Simulation.MODEL_MONTE_CARLO, "%s cruza (llegadas de Poisson, λ = %.2f/s)" % [
				definition.id, 1.0 / definition.mean_gap_seconds])
		return
	global_position = global_position.move_toward(_lane_to, definition.lane_speed * delta)
	if global_position.is_equal_approx(_lane_to):
		_animated_sprite.visible = false
		_lane_wait = Simulation.rng.exponential(1.0 / definition.mean_gap_seconds)


## Runs once physics is ready: finds how far the road goes both ways from the placed position.
func _setup_lane() -> void:
	_lane_ready = true
	var axis: Vector2 = lane_direction.normalized()
	if axis.is_zero_approx():
		var along_x: float = _free_run(Vector2.RIGHT) + _free_run(Vector2.LEFT)
		var along_y: float = _free_run(Vector2.DOWN) + _free_run(Vector2.UP)
		axis = Vector2.RIGHT if along_x >= along_y else Vector2.DOWN
		if Simulation.rng.next() < 0.5:
			axis = -axis
	_lane_heading = axis
	_lane_from = global_position - axis * _free_run(-axis)
	_lane_to = global_position + axis * _free_run(axis)
	_animated_sprite.play(_animation_for_direction(axis))
	# Start somewhere along the lane, so not every car enters at the same moment.
	global_position = _lane_from.lerp(_lane_to, Simulation.rng.next())


## Distance the vehicle can drive from here along [param direction]: up to a wall or prop, or
## past the level edge until the whole sprite is off screen.
func _free_run(direction: Vector2) -> float:
	var reach: float = maxf(_level_rect.size.x, _level_rect.size.y) if _level_rect.has_area() else 2000.0
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, global_position + direction * reach, PhysicsLayers.ENEMY_BLOCKERS)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	var half: float = absf(direction.dot(_sprite_half))
	if hit.is_empty():
		return reach
	var distance: float = global_position.distance_to(hit.position)
	if hit.collider is LevelBounds:
		return distance + half * 2.0  # Drive off screen.
	return maxf(distance - half, 0.0)


func _find_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	return _player


func _report_walk_once() -> void:
	if _has_reported_walk or _brain.state != HostileBrain.State.PATROL:
		return
	_has_reported_walk = true
	Simulation.report(Simulation.MODEL_RANDOM_WALK, "%s patrulla con caminata aleatoria" % definition.id)


func _on_brain_state_changed(new_state: HostileBrain.State) -> void:
	_alert.visible = new_state == HostileBrain.State.CHASE
	_animated_sprite.modulate = COOLDOWN_TINT if new_state == HostileBrain.State.COOLDOWN else Color.WHITE
	if new_state == HostileBrain.State.CHASE:
		Simulation.report(Simulation.MODEL_AGENTS, "%s detecta al jugador y lo persigue" % definition.id)


## Debug builds only: the vision area of chasers (a diamond, because the radius is Manhattan).
func _draw() -> void:
	if not OS.is_debug_build() or definition == null or not definition.behavior.chases:
		return
	var reach: float = (definition.behavior.vision_radius + 0.5) * GridUtils.CELL_SIZE
	var corners: PackedVector2Array = [
		Vector2(0.0, -reach), Vector2(reach, 0.0), Vector2(0.0, reach), Vector2(-reach, 0.0), Vector2(0.0, -reach),
	]
	draw_polyline(corners, DEBUG_VISION_COLOR, 1.0)
