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

@onready var _bounds: LevelBounds = $Setup/LevelBounds
@onready var _player: Player = $World/Entities/Player
@onready var _spawn_point: Marker2D = $Setup/SpawnPoint
@onready var _exit_zone: ExitZone = $World/Triggers/ExitZone


func _ready() -> void:
	_validate_layout()
	_player.global_position = _spawn_point.global_position
	_player.camera.set_level_bounds(level_size)
	_bounds.build(Vector2(level_size))
	_exit_zone.player_entered.connect(_on_exit_reached)
	Simulation.flows_enabled = consumes_resources
	Simulation.begin_level(_get_travel_distance())
	_ensure_playing_state()


func _validate_layout() -> void:
	var level_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(level_size))
	assert(level_rect.has_point(_spawn_point.global_position), "%s: SpawnPoint is outside level_size." % name)
	assert(level_rect.has_point(_exit_zone.global_position), "%s: ExitZone is outside level_size." % name)


func _get_travel_distance() -> float:
	var distance: float = travel_distance
	if distance <= 0.0:
		var offset: Vector2 = (_exit_zone.global_position - _spawn_point.global_position).abs()
		distance = offset.x + offset.y
	return maxf(distance, MIN_TRAVEL_DISTANCE)


func _ensure_playing_state() -> void:
	if GameManager.current_state == GameState.Type.MENU:
		GameManager.change_state(GameState.Type.PLAYING)


func _on_exit_reached() -> void:
	Simulation.end_level(name)
	EventBus.level_completed.emit()
