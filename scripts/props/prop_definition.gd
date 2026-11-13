@tool
class_name PropDefinition
extends Resource
## Static data of an object.

## Size in pixels of one art tile.
const ART_TILE: int = 16
## Art is drawn at half resolution and shown x2, like the characters.
const DEFAULT_DISPLAY_SCALE: int = 1

@export var texture: Texture2D
@export_range(1, 8, 1) var display_scale: int = DEFAULT_DISPLAY_SCALE

@export_group("Collision")
## False for objects the player can walk over.
@export var is_solid: bool = true
## Ground area that blocks movement.
@export var footprint: Rect2 = Rect2()
