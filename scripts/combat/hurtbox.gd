class_name Hurtbox
extends Area2D
## Passive area that receives hits. Hitboxes scan it.

signal hit_received(source: Node)


func _ready() -> void:
	collision_layer = PhysicsLayers.HURTBOX
	collision_mask = 0
	monitoring = false


## Called by whoever hits.
func receive_hit(source: Node) -> void:
	hit_received.emit(source)
