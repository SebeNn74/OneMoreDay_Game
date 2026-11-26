class_name FlavorInteractable
extends Interactable
## Something of the house the player can look at: shows a short text and changes no resource
## (design doc, section 8: home objects are visual). Builds its own shape and, optionally, a sprite.
## Each interaction shows the next line of [member lines].

const SHAPE_SIZE: Vector2 = Vector2(28.0, 28.0)
const SPRITE_SCALE: float = 2.0

## Player-visible texts (Spanish), shown in order and then repeated.
@export_multiline var lines: PackedStringArray = []
## Drawn at this node (for objects that are not already a Prop, like the calendar).
@export var texture: Texture2D
@export var sprite_offset: Vector2 = Vector2.ZERO

var _next_line: int = 0


func _ready() -> void:
	super()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = SHAPE_SIZE
	shape.shape = rect
	add_child(shape)
	if texture != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE * SPRITE_SCALE
		sprite.position = sprite_offset
		add_child(sprite)


func _on_interact(_interactor: Node) -> void:
	if lines.is_empty():
		return
	EventBus.notification_requested.emit(lines[_next_line])
	_next_line = (_next_line + 1) % lines.size()
