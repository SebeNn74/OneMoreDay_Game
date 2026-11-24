class_name BaseLevel
extends Node2D
## Template for every playable level.
## Places the player at the spawn point, limits the camera to the level and
## announces when the exit is reached.

## Size of one screen in pixels.
const SCREEN_SIZE: Vector2i = Vector2i(640, 360)
## Smallest travel distance accepted, so a badly placed exit cannot make the flows explode.
const MIN_TRAVEL_DISTANCE: float = 64.0

## False for levels that cost nothing.
@export var consumes_resources: bool = true
@export var level_size: Vector2i = SCREEN_SIZE
@export_range(0.0, 10000.0, 1.0, "suffix:px") var travel_distance: float = 0.0
## What the player has to do here, shown when the level starts (player-visible, Spanish).
@export_multiline var objective: String = "Llega a la salida"

@onready var _bounds: LevelBounds = $Setup/LevelBounds
@onready var _floor: Sprite2D = $World/Background/Floor
@onready var _player: Player = $World/Entities/Player
@onready var _spawn_point: Marker2D = $Setup/SpawnPoint
@onready var _exit_zone: ExitZone = $World/Triggers/ExitZone
## The trigger area itself: levels move this shape, not always the ExitZone node.
@onready var _exit_shape: CollisionShape2D = $World/Triggers/ExitZone/CollisionShape2D


func _ready() -> void:
	_validate_layout()
	_player.global_position = _spawn_point.global_position
	_player.camera.set_level_bounds(level_size)
	_bounds.build(Vector2(level_size))
	_exit_zone.player_entered.connect(_on_exit_reached)
	EventBus.decision_resolved.connect(_on_route_decision_resolved)
	Simulation.flows_enabled = consumes_resources
	Simulation.begin_level(_get_travel_distance())
	_ensure_playing_state()


func _validate_layout() -> void:
	var level_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(level_size))
	assert(level_rect.has_point(_spawn_point.global_position), "%s: SpawnPoint is outside level_size." % name)
	assert(level_rect.has_point(_exit_shape.global_position), "%s: ExitZone is outside level_size." % name)
	_warn_if_floor_does_not_fit()
	

## Art pipeline check: the floor art must start at (0, 0) and cover exactly the level.
func _warn_if_floor_does_not_fit() -> void:
	if _floor.texture == null:
		return
	if _floor.centered:
		push_warning("%s: Floor has Centered on. Turn it off and set its position to (0, 0)." % name)
	var art_size: Vector2i = Vector2i(_floor.texture.get_size() * _floor.scale)
	if art_size != level_size:
		push_warning("%s: floor art covers %s px but level_size is %s. Set level_size to the art size." % [
			name, art_size, level_size])


func _get_travel_distance() -> float:
	var distance: float = travel_distance
	if distance <= 0.0:
		var offset: Vector2 = (_exit_shape.global_position - _spawn_point.global_position).abs()
		distance = offset.x + offset.y
	return maxf(distance, MIN_TRAVEL_DISTANCE)


func _ensure_playing_state() -> void:
	if GameManager.current_state == GameState.Type.MENU:
		GameManager.change_state(GameState.Type.PLAYING)


## A route option (bus, taxi) leaves the level right away, without walking to the exit.
func _on_route_decision_resolved(_decision: DecisionDefinition, option: DecisionOption) -> void:
	if option.next_scene.is_empty():
		return
	if option.minigame != null:
		await get_tree().process_frame  # Let the decision panel close first.
		var ride: Minigame = option.minigame.instantiate() as Minigame
		add_child(ride)
		await ride.finished
	Simulation.end_level(name)
	SceneManager.jump_to(option.next_scene)


## Where the guide arrow points: the exit, or nothing while it is locked.
## Levels with a locked exit override it to point at what unlocks it.
func get_guide_target() -> Variant:
	if _exit_zone.locked:
		return null
	return _exit_shape.global_position


func _on_exit_reached() -> void:
	Simulation.end_level(name)
	EventBus.level_completed.emit()
