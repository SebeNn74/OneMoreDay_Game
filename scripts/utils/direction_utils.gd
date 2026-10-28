@tool
class_name DirectionUtils
extends RefCounted
## Helpers for the 4 cardinal directions used by sprites and facing logic.

const DOWN: StringName = &"down"
const UP: StringName = &"up"
const LEFT: StringName = &"left"
const RIGHT: StringName = &"right"


## Snaps a non-zero vector to the closest cardinal direction. Ties favor vertical.
static func to_cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP


## Animation suffix of a cardinal direction (e.g. Vector2.LEFT -> "left").
static func name_of(cardinal: Vector2) -> StringName:
	match cardinal:
		Vector2.UP:
			return UP
		Vector2.LEFT:
			return LEFT
		Vector2.RIGHT:
			return RIGHT
	return DOWN
