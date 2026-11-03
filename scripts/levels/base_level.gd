class_name BaseLevel
extends Node2D
## Template for every playable level.
## Places the player at the spawn point and announces when the exit is reached.
## Level-specific logic goes in a script that extends this one.

@onready var _player: Player = $Entities/Player
@onready var _spawn_point: Marker2D = $SpawnPoint
@onready var _exit_zone: ExitZone = $ExitZone


func _ready() -> void:
	_player.global_position = _spawn_point.global_position
	_exit_zone.player_entered.connect(_on_exit_reached)


func _on_exit_reached() -> void:
	EventBus.level_completed.emit()
