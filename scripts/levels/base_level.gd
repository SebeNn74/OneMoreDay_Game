class_name BaseLevel
extends Node2D
## Template for every playable level.
## Places the player at the spawn point, limits the camera to the level and
## announces when the exit is reached.

## Size of one screen in pixels.
const SCREEN_SIZE: Vector2i = Vector2i(640, 360)
## Width of a regular level, in screens. The home overrides level_size with one screen.
const DEFAULT_SCREEN_COUNT: int = 3

## False for levels that cost nothing.
@export var consumes_resources: bool = true
@export var level_size: Vector2i = Vector2i(SCREEN_SIZE.x * DEFAULT_SCREEN_COUNT, SCREEN_SIZE.y)

@onready var _bounds: LevelBounds = $Setup/LevelBounds
@onready var _player: Player = $World/Entities/Player
@onready var _spawn_point: Marker2D = $Setup/SpawnPoint
@onready var _exit_zone: ExitZone = $World/Triggers/ExitZone


func _ready() -> void:
	_player.global_position = _spawn_point.global_position
	_player.camera.set_level_bounds(level_size)
	_bounds.build(Vector2(level_size))
	_exit_zone.player_entered.connect(_on_exit_reached)
	Simulation.flows_enabled = consumes_resources
	_ensure_playing_state()


func _ensure_playing_state() -> void:
	if GameManager.current_state == GameState.Type.MENU:
		GameManager.change_state(GameState.Type.PLAYING)


func _on_exit_reached() -> void:
	EventBus.level_completed.emit()
