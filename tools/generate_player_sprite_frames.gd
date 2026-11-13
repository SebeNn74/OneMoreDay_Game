
@tool
extends EditorScript
class_name SpriteFramesGenerator

## Directorio donde se encuentran los spritesheets.
const DEFAULT_SHEETS_DIR: String = "res://assets/sprites/"

## Configuración de las animaciones.
## Cada entrada representa un spritesheet.
const ANIMATIONS: Array[Dictionary] = [
	{
		"name": "phone",
		"sheet": "environment/home/spr_celular.png",
		"cell_size": Vector2i(8, 10),
		"frames": 2,
		"fps": 6.0,
		"loop": true
	},
	{
		"name": "window",
		"sheet": "environment/home/anim_ventana.png",
		"cell_size": Vector2i(128, 64),
		"frames": 2,
		"fps": 6.0,
		"loop": true
	},
]


## Configuración general de generación.
const OUTPUT_PATH: String = "res://assets/sprites/environment/home/home_sprite_frames.tres"
const SHEETS_DIR: String = DEFAULT_SHEETS_DIR


func _run() -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")

	for spec: Dictionary in ANIMATIONS:
		if not _add_animation(sprite_frames, spec):
			push_error("Generation aborted. Check the configuration.")
			return

	var error := ResourceSaver.save(sprite_frames, OUTPUT_PATH)

	if error != OK:
		push_error("Could not save resource: %s (error %d)." % [
			OUTPUT_PATH,
			error
		])
		return

	EditorInterface.get_resource_filesystem().scan()

	print(
		"SpriteFrames generated successfully: %s (%d animations)"
		% [OUTPUT_PATH, sprite_frames.get_animation_names().size()]
	)


## Processes one spritesheet.
func _add_animation(
	sprite_frames: SpriteFrames,
	spec: Dictionary
) -> bool:

	# Required configuration.
	var required := ["name", "sheet", "cell_size", "frames"]

	for key: String in required:
		if not spec.has(key):
			push_error("Missing configuration property: %s" % key)
			return false

	# Load texture.
	var sheet_path: String = SHEETS_DIR + str(spec.sheet)
	var texture := load(sheet_path) as Texture2D

	if texture == null:
		push_error("Could not load spritesheet: %s" % sheet_path)
		return false

	# Read configuration.
	var cell_size: Vector2i = spec.cell_size
	var frame_count: int = spec.frames
	var fps: float = spec.get("fps", 8.0)
	var loop: bool = spec.get("loop", true)
	var directions: Dictionary = spec.get("directions", {})

	# Validate configuration.
	if cell_size.x <= 0 or cell_size.y <= 0:
		push_error("Invalid cell size in: %s" % spec.name)
		return false

	if frame_count <= 0 or fps <= 0:
		push_error("Invalid frame count or FPS in: %s" % spec.name)
		return false

	# Calculate expected dimensions.
	var rows: int = 1

	if not directions.is_empty():
		for row: Variant in directions.values():
			rows = maxi(rows, int(row) + 1)

	var expected_size := Vector2i(
		frame_count * cell_size.x,
		rows * cell_size.y
	)

	var actual_size := Vector2i(texture.get_size())

	if actual_size != expected_size:
		push_error(
			"Invalid spritesheet size: %s. Expected: %s, Got: %s"
			% [sheet_path, expected_size, actual_size]
		)
		return false

	# Generate animations.
	if directions.is_empty():
		_add_clip(
			sprite_frames,
			str(spec.name),
			texture,
			cell_size,
			0,
			spec
		)
	else:
		for direction: Variant in directions:
			var animation_name := "%s_%s" % [
				spec.name,
				direction
			]

			_add_clip(
				sprite_frames,
				animation_name,
				texture,
				cell_size,
				int(directions[direction]),
				spec
			)

	return true


## Generates one animation from a spritesheet row.
func _add_clip(
	sprite_frames: SpriteFrames,
	clip_name: String,
	texture: Texture2D,
	cell_size: Vector2i,
	row: int,
	spec: Dictionary
) -> void:

	if sprite_frames.has_animation(clip_name):
		push_error("Duplicate animation name: %s" % clip_name)
		return

	sprite_frames.add_animation(clip_name)

	sprite_frames.set_animation_speed(
		clip_name,
		float(spec.get("fps", 8.0))
	)

	sprite_frames.set_animation_loop(
		clip_name,
		bool(spec.get("loop", true))
	)

	for column: int in range(int(spec.frames)):
		var frame := AtlasTexture.new()

		frame.atlas = texture

		frame.region = Rect2(
			column * cell_size.x,
			row * cell_size.y,
			cell_size.x,
			cell_size.y
		)

		sprite_frames.add_frame(clip_name, frame)
