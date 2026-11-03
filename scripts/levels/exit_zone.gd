class_name ExitZone
extends Area2D
## Trigger area that reports when the player reaches it. Fires only once.

signal player_entered


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		set_deferred("monitoring", false)  # Cannot change physics state mid-callback.
		player_entered.emit()
