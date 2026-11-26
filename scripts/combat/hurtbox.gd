class_name Hurtbox
extends Area2D
## Passive area that receives hits. Hitboxes scan it.

signal hit_received(source: Node)


func _ready() -> void:
	collision_layer = PhysicsLayers.HURTBOX
	collision_mask = 0
	monitoring = false


## Seconds left during which hits are ignored (level start: never get hit while still fading in).
var _grace_left: float = 0.0


func _process(delta: float) -> void:
	_grace_left = maxf(_grace_left - delta, 0.0)


func grant_grace(seconds: float) -> void:
	_grace_left = maxf(_grace_left, seconds)


func is_vulnerable() -> bool:
	return _grace_left <= 0.0


func grace_left() -> float:
	return _grace_left


## Called by whoever hits.
func receive_hit(source: Node) -> void:
	hit_received.emit(source)
