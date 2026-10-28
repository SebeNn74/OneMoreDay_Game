@tool
extends EditorScript
## Builds the player's SpriteFrames from the sprite sheets.
## Run: open this file in the Script editor, then File > Run (Ctrl+Shift+X).
## Re-run whenever P3 delivers new sheets or the table below changes.
##
## Generated names (read by PlayerAnimator):
##   directional sheets     -> "<state>_<direction>"  e.g. walk_left
##   non-directional sheets -> "<state>"              e.g. hurt

const SHEETS_DIR: String = "res://assets/sprites/player/"
const OUTPUT_PATH: String = "res://assets/sprites/player/player_sprite_frames.tres"
const DEFAULT_CELL_SIZE: Vector2i = Vector2i(16, 24)

## Row of each direction inside directional sheets (top to bottom).
## If a direction looks wrong in game, swap the numbers here and re-run.
const DIRECTION_ROWS: Dictionary = {
	DirectionUtils.DOWN: 0,
	DirectionUtils.UP: 1,
	DirectionUtils.LEFT: 2,
	DirectionUtils.RIGHT: 3,
}

## One entry per animation.
## cell: size of one frame (optional, defaults to DEFAULT_CELL_SIZE).
const ANIMATIONS: Array[Dictionary] = [
	{ name = "idle", sheet = "player_idle.png", frames = 2, fps = 3.0, loop = true, directional = true },
	{ name = "walk", sheet = "player_walk.png", frames = 4, fps = 8.0, loop = true, directional = true },
	# TODO(P3): placeholder. Reuses the walk sheet faster until player_run.png exists.
	{ name = "run", sheet = "player_walk.png", frames = 4, fps = 12.0, loop = true, directional = true },
	{ name = "interact", sheet = "player_interact.png", frames = 3, fps = 6.0, loop = false, directional = false },
	{ name = "hurt", sheet = "player_hurt.png", frames = 2, fps = 6.0, loop = false, directional = false },
	{ name = "fall", sheet = "player_fall.png", cell = Vector2i(24, 24), frames = 4, fps = 6.0, loop = false, directional = false },
]


func _run() -> void:
	var sprite_frames: SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation(&"default")

	for spec: Dictionary in ANIMATIONS:
		if not _add_animation(sprite_frames, spec):
			push_error("Generation aborted. Fix the error above and run again.")
			return

	var error: Error = ResourceSaver.save(sprite_frames, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save %s (error %d)." % [OUTPUT_PATH, error])
		return

	EditorInterface.get_resource_filesystem().scan()
	print("Saved %s with %d animations." % [OUTPUT_PATH, sprite_frames.get_animation_names().size()])


## Returns false if the sheet is missing or its size does not match the table.
func _add_animation(sprite_frames: SpriteFrames, spec: Dictionary) -> bool:
	var texture: Texture2D = load(SHEETS_DIR + str(spec.sheet))
	if texture == null:
		push_error("Missing sheet: %s" % spec.sheet)
		return false

	var cell_size: Vector2i = spec.get("cell", DEFAULT_CELL_SIZE)
	var rows: int = DIRECTION_ROWS.size() if spec.directional else 1
	var expected_size: Vector2i = Vector2i(spec.frames * cell_size.x, rows * cell_size.y)
	var actual_size: Vector2i = Vector2i(texture.get_size())
	if actual_size != expected_size:
		push_error("%s is %s but the table expects %s (check cell size and frame count)." % [spec.sheet, actual_size, expected_size])
		return false

	if spec.directional:
		for direction: StringName in DIRECTION_ROWS:
			var clip_name: String = "%s_%s" % [spec.name, direction]
			_add_clip(sprite_frames, clip_name, texture, cell_size, DIRECTION_ROWS[direction], spec)
	else:
		_add_clip(sprite_frames, str(spec.name), texture, cell_size, 0, spec)
	return true


func _add_clip(sprite_frames: SpriteFrames, clip_name: String, texture: Texture2D, cell_size: Vector2i, row: int, spec: Dictionary) -> void:
	sprite_frames.add_animation(clip_name)
	sprite_frames.set_animation_speed(clip_name, spec.fps)
	sprite_frames.set_animation_loop(clip_name, spec.loop)

	for column: int in range(spec.frames):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(column * cell_size.x, row * cell_size.y, cell_size.x, cell_size.y)
		sprite_frames.add_frame(clip_name, frame)
