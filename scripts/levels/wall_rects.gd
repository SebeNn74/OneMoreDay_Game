@tool
class_name WallRects
extends StaticBody2D
## Solid walls typed as rectangles.

@export var rects: Array[Rect2i] = []:
	set(value):
		rects = value
		if is_node_ready():
			_rebuild()


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	for rect: Rect2i in rects:
		if not rect.has_area():
			continue
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(rect.size)
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.shape = shape
		collision.position = Vector2(rect.position)
		add_child(collision)
