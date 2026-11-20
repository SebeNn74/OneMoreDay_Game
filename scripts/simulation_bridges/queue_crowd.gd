class_name QueueCrowd
extends Node2D
## The people standing in a queue. How many = the mean queue length Lq of the M/M/1 model.

const PERSON_SIZE: Vector2 = Vector2(32.0, 48.0)
const CROWD_DEFINITIONS: Array[HostileDefinition] = [
	preload("res://data/hostiles/h_crowd_a.tres"),
	preload("res://data/hostiles/h_crowd_b.tres"),
	preload("res://data/hostiles/h_crowd_c.tres"),
]

@export var queue: QueueConfig
## Direction in which the line grows (any non-zero vector).
@export var direction: Vector2 = Vector2.LEFT
## Distance in pixels between consecutive people.
@export_range(8.0, 96.0, 1.0, "suffix:px") var spacing: float = 36.0
## Direction the people face.
@export var facing_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	assert(queue != null, "%s: queue is not assigned." % name)
	assert(direction != Vector2.ZERO, "%s: queue direction cannot be zero." % name)
	assert(facing_direction != Vector2.ZERO, "%s: facing direction cannot be zero." % name)
	var people: int = roundi(QueueModel.mean_queue_length(queue))
	var step: Vector2 = direction.normalized() * spacing
	for index: int in people:
		_add_person(index, step * index)


func _add_person(index: int, feet: Vector2) -> void:
	var definition: HostileDefinition = CROWD_DEFINITIONS[index % CROWD_DEFINITIONS.size()]
	assert(definition.sprite_frames != null, "%s: %s has no SpriteFrames." % [name, definition.id])
	var direction_name: StringName = DirectionUtils.name_of(DirectionUtils.to_cardinal(facing_direction))
	var animation_name: StringName = StringName("%s_%s" % [definition.sprite_animation, direction_name])
	assert(
		definition.sprite_frames.has_animation(animation_name),
		"%s: %s has no animation '%s'." % [name, definition.id, animation_name]
	)

	var frame: Texture2D = definition.sprite_frames.get_frame_texture(animation_name, 0)
	var frame_size: Vector2 = frame.get_size()
	var sprite_scale: float = minf(PERSON_SIZE.x / frame_size.x, PERSON_SIZE.y / frame_size.y)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = definition.sprite_frames
	sprite.animation = animation_name
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = feet + Vector2(0.0, -frame_size.y * sprite_scale / 2.0)
	add_child(sprite)
	sprite.play(animation_name)
