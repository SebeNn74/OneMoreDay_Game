class_name QueueCrowd
extends Node2D
## The people standing in a queue. How many = the mean queue length Lq of the M/M/1 model.

const PERSON_SIZE: Vector2 = Vector2(32.0, 48.0)
const PERSON_COLOR: Color = Color(0.45, 0.5, 0.65)
const OUTLINE_COLOR: Color = Color(0.2, 0.22, 0.3)

@export var queue: QueueConfig
## Direction in which the line grows (any non-zero vector).
@export var direction: Vector2 = Vector2.LEFT
## Distance in pixels between consecutive people.
@export_range(8.0, 96.0, 1.0, "suffix:px") var spacing: float = 36.0


func _ready() -> void:
	assert(queue != null, "%s: queue is not assigned." % name)
	queue_redraw()


func _draw() -> void:
	if queue == null:
		return
	var people: int = roundi(QueueModel.mean_queue_length(queue))
	var step: Vector2 = direction.normalized() * spacing
	for index: int in people:
		var feet: Vector2 = step * index
		var box: Rect2 = Rect2(feet + Vector2(-PERSON_SIZE.x / 2.0, -PERSON_SIZE.y), PERSON_SIZE)
		draw_rect(box, PERSON_COLOR)
		draw_rect(box, OUTLINE_COLOR, false)
