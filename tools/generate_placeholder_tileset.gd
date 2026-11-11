@tool
extends EditorScript
## Builds a placeholder TileSet until P3 delivers real tiles:
## floor (no collision), wall (physics layer 0 = world), prop (physics layer 1 = decoration).
## Run: open this file in the Script editor, then File > Run (Ctrl+Shift+X).

const OUTPUT_PATH: String = "res://assets/sprites/environment/placeholder_tileset.tres"
const TILE_SIZE: int = 20  # Pending decision with P3.
const ATLAS_COLUMNS: int = 3

const FLOOR_TILE: Vector2i = Vector2i(0, 0)
const WALL_TILE: Vector2i = Vector2i(1, 0)
const PROP_TILE: Vector2i = Vector2i(2, 0)

const WORLD_PHYSICS_LAYER: int = 0
const DECORATION_PHYSICS_LAYER: int = 1

const FLOOR_FILL: Color = Color(0.30, 0.32, 0.38)
const FLOOR_BORDER: Color = Color(0.26, 0.28, 0.33)
const WALL_FILL: Color = Color(0.45, 0.30, 0.22)
const WALL_BORDER: Color = Color(0.30, 0.20, 0.15)
const PROP_FILL: Color = Color(0.25, 0.45, 0.35)
const PROP_BORDER: Color = Color(0.15, 0.30, 0.22)


func _run() -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_add_physics_layer(tile_set, WORLD_PHYSICS_LAYER, PhysicsLayers.WORLD)
	_add_physics_layer(tile_set, DECORATION_PHYSICS_LAYER, PhysicsLayers.DECORATION)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = _build_atlas_texture()
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source)  # Must happen before editing tile data.

	source.create_tile(FLOOR_TILE)
	source.create_tile(WALL_TILE)
	source.create_tile(PROP_TILE)
	_add_solid_collision(source.get_tile_data(WALL_TILE, 0), WORLD_PHYSICS_LAYER)
	_add_solid_collision(source.get_tile_data(PROP_TILE, 0), DECORATION_PHYSICS_LAYER)

	var error: Error = ResourceSaver.save(tile_set, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save %s (error %d)." % [OUTPUT_PATH, error])
		return

	EditorInterface.get_resource_filesystem().scan()
	print("Saved %s (tile size %d)." % [OUTPUT_PATH, TILE_SIZE])


func _add_physics_layer(tile_set: TileSet, index: int, collision_layer: int) -> void:
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(index, collision_layer)
	tile_set.set_physics_layer_collision_mask(index, 0)


func _build_atlas_texture() -> ImageTexture:
	var image: Image = Image.create_empty(TILE_SIZE * ATLAS_COLUMNS, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_paint_tile(image, FLOOR_TILE, FLOOR_FILL, FLOOR_BORDER)
	_paint_tile(image, WALL_TILE, WALL_FILL, WALL_BORDER)
	_paint_tile(image, PROP_TILE, PROP_FILL, PROP_BORDER)
	return ImageTexture.create_from_image(image)


func _paint_tile(image: Image, atlas_coords: Vector2i, fill: Color, border: Color) -> void:
	var tile_rect: Rect2i = Rect2i(atlas_coords * TILE_SIZE, Vector2i(TILE_SIZE, TILE_SIZE))
	image.fill_rect(tile_rect, border)
	image.fill_rect(tile_rect.grow(-1), fill)


## Full-tile square collision on the given physics layer.
func _add_solid_collision(tile_data: TileData, physics_layer: int) -> void:
	var half: float = TILE_SIZE / 2.0
	tile_data.add_collision_polygon(physics_layer)
	tile_data.set_collision_polygon_points(physics_layer, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	]))
