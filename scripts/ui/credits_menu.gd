class_name CreditsMenu
extends CanvasLayer
## Credits, opened from the main menu: the team and the third-party assets with their licenses
## (the full audio table is in assets/audio/CREDITS.md). Esc, the pause key or VOLVER close it.

signal closed

const DRAW_LAYER: int = 95
const PANEL_WIDTH: float = 520.0
const ACCENT: Color = Color(1.0, 0.85, 0.3)
const MUTED: Color = Color(0.8, 0.8, 0.8)
## Player-visible texts (Spanish).
const TITLE: String = "CRÉDITOS"
const SUBTITLE: String = "One More Day · Simulación por computador · UPTC · 2026"
const TEAM: Array = [  # [name, role]
	["Sebastián Niño Niño", "Programación principal"],
	["Kevin Johann Jiménez Poveda", "Modelos de simulación"],
	["Andrés Felipe Melo Avellaneda", "Arte y animación"],
	["Miguel Leonardo Ávila Ávila", "Eventos y narrativa"],
	["Laura Correa", "Interfaz, audio e integración"],
]
const ASSETS: PackedStringArray = [
	"Música (OpenGameArt, CC0): Juhani Junkala, tomcat, matiasvme, wolfgang, cleytonkauffman.",
	"Efectos y ambientes (CC0): Kenney (kenney.nl); en OpenGameArt: IgnasD, ggbotnet, LEGIT Audio, johndekale, ezduzziteh y Zane Little Music.",
	"Fuente: Pixel Operator, de Jayvee Enaguas (CC0). Motor: Godot Engine 4 (MIT).",
	"Arte del juego: original del equipo.",
]
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
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	box.add_child(_label(TITLE, ACCENT, 0, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(SUBTITLE, MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(HSeparator.new())
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	for member: Array in TEAM:
		grid.add_child(_label(member[0], Color.WHITE, 12))
		grid.add_child(_label(member[1], MUTED, 12))
	box.add_child(grid)
	box.add_child(HSeparator.new())
	for line: String in ASSETS:
		var label: Label = _label(line, MUTED, 11)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
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
