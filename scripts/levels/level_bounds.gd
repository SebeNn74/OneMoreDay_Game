class_name LevelBounds
extends StaticBody2D
## Invisible walls around the level, so the player can never leave the map
## no matter how the tiles are painted.

const WALL_THICKNESS: float = 32.0


## Builds four walls around the rectangle (0, 0) - level_size.
func build(level_size: Vector2) -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var half_thickness: float = WALL_THICKNESS / 2.0
	var full_width: float = level_size.x + WALL_THICKNESS * 2.0
	var full_height: float = level_size.y + WALL_THICKNESS * 2.0
	_add_wall(Vector2(level_size.x / 2.0, -half_thickness), Vector2(full_width, WALL_THICKNESS))
	_add_wall(Vector2(level_size.x / 2.0, level_size.y + half_thickness), Vector2(full_width, WALL_THICKNESS))
	_add_wall(Vector2(-half_thickness, level_size.y / 2.0), Vector2(WALL_THICKNESS, full_height))
	_add_wall(Vector2(level_size.x + half_thickness, level_size.y / 2.0), Vector2(WALL_THICKNESS, full_height))


func _add_wall(center: Vector2, size: Vector2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = center
	add_child(collision)
