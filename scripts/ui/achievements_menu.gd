class_name AchievementsMenu
extends CanvasLayer
## Achievements screen, opened from the main menu: every achievement with how to get it, in gold
## when unlocked (with the date). Esc, the pause key or VOLVER close it.

signal closed

const DRAW_LAYER: int = 95
const PANEL_WIDTH: float = 600.0
const ACCENT: Color = Color(1.0, 0.85, 0.3)
const LOCKED: Color = Color(0.55, 0.55, 0.6)
## Player-visible texts (Spanish).
const TITLE_FORMAT: String = "LOGROS  %d / %d"
const UNLOCKED_FORMAT: String = "%s  (%s)"
const BACK_TEXT: String = "VOLVER"


func _ready() -> void:
	layer = DRAW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StatFormatter.panel_style())
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var total: int = Achievements.DEFINITIONS.size()
	box.add_child(_label(TITLE_FORMAT % [Achievements.unlocked_count(), total], ACCENT, 0,
		HORIZONTAL_ALIGNMENT_CENTER))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	for id: String in Achievements.DEFINITIONS:
		var spec: Array = Achievements.DEFINITIONS[id]
		var is_unlocked: bool = Achievements.is_unlocked(id)
		var cell: VBoxContainer = VBoxContainer.new()
		cell.add_theme_constant_override("separation", -2)
		cell.custom_minimum_size.x = (PANEL_WIDTH - 40.0) / 2.0
		var title: String = UNLOCKED_FORMAT % [spec[0], Achievements.unlocked_date(id)] if is_unlocked else spec[0]
		cell.add_child(_label(title, ACCENT if is_unlocked else LOCKED, 12))
		cell.add_child(_label(spec[1], Color.WHITE if is_unlocked else LOCKED, 10))
		grid.add_child(cell)
	box.add_child(grid)
	var back: Button = Button.new()
	back.text = BACK_TEXT
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 100.0
	back.pressed.connect(_close)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _label(text: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_color_override("font_color", color)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
