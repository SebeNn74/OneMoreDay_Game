@tool
class_name Prop
extends StaticBody2D
## A piece of furniture or decoration. 
## Place it in World/Entities so it Y-sorts with the player.

@export var definition: PropDefinition:
	set(value):
		definition = value
		_rebuild()

@onready var _sprite: Sprite2D = $Sprite
@onready var _footprint_shape: CollisionShape2D = $Footprint


func _ready() -> void:
	# Set in code so a wrong Inspector value cannot break collisions.
	collision_layer = PhysicsLayers.DECORATION
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if _sprite == null:
		return
	if definition == null or definition.texture == null:
		_sprite.texture = null
		_footprint_shape.shape = null
		return

	var scale_factor: Vector2 = Vector2.ONE * definition.display_scale
	var texture_size: Vector2 = definition.texture.get_size()
	_sprite.texture = definition.texture
	_sprite.centered = false
	_sprite.offset = Vector2(-texture_size.x / 2.0, -texture_size.y)  # Origin at the bottom center.
	_sprite.scale = scale_factor  # Only the sprite is scaled, never the body.
	_rebuild_footprint(scale_factor)


func _rebuild_footprint(scale_factor: Vector2) -> void:
	var footprint: Rect2 = definition.footprint
	if not definition.is_solid or not footprint.has_area():
		_footprint_shape.shape = null
		return
	var shape: RectangleShape2D = RectangleShape2D.new()  # One per Prop: shapes are shared Resources.
	shape.size = footprint.size * scale_factor
	_footprint_shape.shape = shape
	_footprint_shape.position = footprint.get_center() * scale_factor
