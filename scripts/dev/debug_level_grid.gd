extends Node2D
## Debug-only guides with their coordinates: a line every GRID_STEP pixels on both axes plus
## the level outline. Makes camera scrolling visible and helps placing nodes while the
## levels have no art.

const GRID_STEP: int = 80
const DRAW_ORDER: int = -1  # Below the level's own graphics.
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const OUTLINE_COLOR: Color = Color(1.0, 0.3, 0.3, 0.8)
const OUTLINE_WIDTH: float = 2.0
const LABEL_SIZE: int = 12
const LABEL_OFFSET: Vector2 = Vector2(3.0, 14.0)

var _level_size: Vector2i


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	z_index = DRAW_ORDER
	var level: BaseLevel = get_parent().get_parent() as BaseLevel
	assert(level != null, "DebugLevelGrid must be a child of the Debug node of a BaseLevel.")
	_level_size = level.level_size
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var extent: Vector2 = Vector2(_level_size)
	for x: int in range(0, _level_size.x + 1, GRID_STEP):
		draw_line(Vector2(x, 0), Vector2(x, extent.y), LINE_COLOR)
		draw_string(font, Vector2(x, 0) + LABEL_OFFSET, str(x),
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LINE_COLOR)
	for y: int in range(0, _level_size.y + 1, GRID_STEP):
		draw_line(Vector2(0, y), Vector2(extent.x, y), LINE_COLOR)
		if y > 0:  # y = 0 shares its corner with the label of x = 0.
			draw_string(font, Vector2(0, y) + LABEL_OFFSET, str(y),
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LINE_COLOR)
	draw_rect(Rect2(Vector2.ZERO, extent), OUTLINE_COLOR, false, OUTLINE_WIDTH)
