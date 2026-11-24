class_name Hostile
extends Node2D
## A hostile agent. Moves cell by cell following HostileBrain.

const COOLDOWN_TINT: Color = Color(0.6, 0.6, 0.6)
## Square used to test whether a cell is free. Slightly smaller than a cell, so a wall that
## only touches the edge of the cell does not block it.
const CELL_PROBE_SIZE: float = GridUtils.CELL_SIZE - 4.0
const DEBUG_VISION_COLOR: Color = Color(1.0, 0.3, 0.3, 0.6)

@export var definition: HostileDefinition

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

	var hitbox_shape := RectangleShape2D.new()
	hitbox_shape.size = definition.hitbox_size * definition.sprite_scale
	_hitbox_shape.shape = hitbox_shape
	_hitbox_shape.position = definition.hitbox_offset * definition.sprite_scale
	_alert.visible = false

	_probe = RectangleShape2D.new()
	_probe.size = Vector2.ONE * CELL_PROBE_SIZE
	_brain = HostileBrain.new(definition.behavior)
	_brain.state_changed.connect(_on_brain_state_changed)

	_cell = GridUtils.cell_of(global_position)
	_target_position = GridUtils.center_of(_cell)
	global_position = _target_position


func _physics_process(delta: float) -> void:
	if not _can_act():
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
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _probe
	query.transform = Transform2D(0.0, GridUtils.center_of(cell))
	query.collision_mask = PhysicsLayers.ENEMY_BLOCKERS
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	return space.intersect_shape(query, 1).is_empty()


## Polled every frame (not area_entered) so a touch during a dialog is not lost.
func _check_contact() -> void:
	for area: Area2D in _hitbox.get_overlapping_areas():
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox != null and _brain.register_contact():
			_hit(hurtbox)
			return


func _hit(hurtbox: Hurtbox) -> void:
	_cooldown_left = definition.hit_cooldown_seconds
	hurtbox.receive_hit(self)
	Simulation.apply_change(definition.hit_money, definition.hit_energy, definition.hit_time)
	EventBus.hostile_hit.emit(definition)
	Simulation.report(Simulation.MODEL_AGENTS, "%s golpea: E %+.0f, T %+.0f, $ %+.0f" % [
		definition.id, definition.hit_energy, definition.hit_time, definition.hit_money])


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
