extends Node2D
## Debug-only vertical guides with their X coordinate, so camera scrolling is visible
## and events can be placed while the levels still have no art.

const GRID_STEP: int = 80
const DRAW_ORDER: int = -1  # Below the level's own graphics.
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const LABEL_SIZE: int = 12
const LABEL_OFFSET: Vector2 = Vector2(3.0, 14.0)

var _level_size: Vector2i


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	z_index = DRAW_ORDER
	var level: BaseLevel = get_parent().get_parent() as BaseLevel
	assert(level != null, "DebugLevelGrid must be a child of a BaseLevel.")
	_level_size = level.level_size
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for x: int in range(0, _level_size.x + 1, GRID_STEP):
		draw_line(Vector2(x, 0), Vector2(x, _level_size.y), LINE_COLOR)
		draw_string(font, Vector2(x, 0) + LABEL_OFFSET, str(x),
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LINE_COLOR)
