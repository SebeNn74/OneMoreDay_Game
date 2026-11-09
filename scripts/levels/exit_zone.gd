class_name ExitZone
extends Area2D
## Trigger area that reports when the player reaches it. Fires only once.
## While locked, touching it only emits blocked_entered.

signal player_entered
signal blocked_entered

## A locked exit does not fire. Unlocking with the player already inside fires it.
var locked: bool = false:
	set(value):
		locked = value
		if not locked and is_node_ready():
			_fire_if_player_inside()

var _has_fired: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_handle_player_contact()


func _fire_if_player_inside() -> void:
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			_handle_player_contact()
			return


func _handle_player_contact() -> void:
	if _has_fired:
		return
	if locked:
		blocked_entered.emit()
		return
	_has_fired = true
	set_deferred("monitoring", false)  # Cannot change physics state mid-callback.
	player_entered.emit()
