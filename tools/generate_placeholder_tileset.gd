@tool
extends EditorScript
## Builds a placeholder TileSet (floor + wall) until P3 delivers real tiles.

const OUTPUT_PATH: String = "res://assets/sprites/environment/placeholder_tileset.tres"
const TILE_SIZE: int = 20

const FLOOR_TILE: Vector2i = Vector2i(0, 0)
const WALL_TILE: Vector2i = Vector2i(1, 0)

const FLOOR_FILL: Color = Color(0.30, 0.32, 0.38)
const FLOOR_BORDER: Color = Color(0.26, 0.28, 0.33)
const WALL_FILL: Color = Color(0.45, 0.30, 0.22)
const WALL_BORDER: Color = Color(0.30, 0.20, 0.15)


func _run() -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, PhysicsLayers.WORLD)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = _build_atlas_texture()
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source)  # Must happen before editing tile data.

	source.create_tile(FLOOR_TILE)
	source.create_tile(WALL_TILE)
	_add_solid_collision(source.get_tile_data(WALL_TILE, 0))

	var error: Error = ResourceSaver.save(tile_set, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save %s (error %d)." % [OUTPUT_PATH, error])
		return

	EditorInterface.get_resource_filesystem().scan()
	print("Saved %s (tile size %d)." % [OUTPUT_PATH, TILE_SIZE])


func _build_atlas_texture() -> ImageTexture:
	var image: Image = Image.create_empty(TILE_SIZE * 2, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_paint_tile(image, FLOOR_TILE, FLOOR_FILL, FLOOR_BORDER)
	_paint_tile(image, WALL_TILE, WALL_FILL, WALL_BORDER)
	return ImageTexture.create_from_image(image)


func _paint_tile(image: Image, atlas_coords: Vector2i, fill: Color, border: Color) -> void:
	var tile_rect: Rect2i = Rect2i(atlas_coords * TILE_SIZE, Vector2i(TILE_SIZE, TILE_SIZE))
	image.fill_rect(tile_rect, border)
	image.fill_rect(tile_rect.grow(-1), fill)


## Full-tile square collision on physics layer 0.
func _add_solid_collision(tile_data: TileData) -> void:
	var half: float = TILE_SIZE / 2.0
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	]))
