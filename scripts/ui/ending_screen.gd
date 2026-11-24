class_name EndingScreen
extends Control
## Ending of the finished day: illustration plus its text.
## Which one comes from EndingResolver, using what RunLog recorded. The victory and the defeat
## of the day sequence both point to this scene.

const CATALOG: EndingCatalog = preload("res://data/endings/ending_catalog.tres")
## Player-visible texts (Spanish).
const TITLE_VICTORY: String = "¡Llegaste a casa!"
const TITLE_DEFEAT: String = "No lograste completar el día."
const VICTORY_COLOR: Color = Color(0.55, 0.9, 0.55)
const DEFEAT_COLOR: Color = Color(0.95, 0.5, 0.45)
const HINT_TEXT: String = "[{interact}] Volver a empezar   [{pause}] Menú principal"
const RESTART_TEXT: String = "VOLVER A EMPEZAR"
const MENU_TEXT: String = "MENÚ PRINCIPAL"
const SUMMARY_TITLE: String = "Resumen del día"
const SUMMARY_FORMAT: String = "Decisiones: %d   Eventos: %d   Golpes: %d
Riesgos tomados: %d (salieron mal %d)"
const SUMMARY_WIDTH: float = 230.0
## The text appears letter by letter: pause before it starts, seconds per character and a cap.
const REVEAL_DELAY_SECONDS: float = 0.4
const REVEAL_SECONDS_PER_CHARACTER: float = 0.03
const MAX_REVEAL_SECONDS: float = 3.0
## Input is ignored this long after the screen opens, so a key still pressed does not skip it.
const INPUT_DELAY_SECONDS: float = 0.6

## For testing the scene alone (F6): id of the ending to show when there is no finished day.
@export var preview_ending_id: String = ""

@onready var _illustration: TextureRect = %Illustration
@onready var _title_label: Label = %TitleLabel
@onready var _text_label: Label = %TextLabel
@onready var _hint_label: Label = $Backdrop/Margin/VBox/HintLabel

var _reveal_tween: Tween
var _opened_at_ms: int = 0


func _ready() -> void:
	_opened_at_ms = Time.get_ticks_msec()
	var ending: EndingDefinition = _pick_ending()
	print("[Ending] %s (%s)" % [ending.id, "victoria" if ending.is_victory else "derrota"])
	_illustration.texture = ending.image
	_title_label.text = TITLE_VICTORY if ending.is_victory else TITLE_DEFEAT
	_title_label.add_theme_color_override("font_color", VICTORY_COLOR if ending.is_victory else DEFEAT_COLOR)
	_text_label.text = ending.text
	_hint_label.text = Settings.with_keys(HINT_TEXT)
	_add_buttons()
	if SceneManager.last_result != null:
		var summary: RunSummary = RunLog.build_summary(SceneManager.last_result)
		_add_summary(summary)
		Achievements.on_day_ended(ending.id, summary)
	_start_reveal(ending.text.length())


## Mouse users get buttons too (keys: interact restarts, pause goes to the menu).
func _add_buttons() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	for spec: Array in [[RESTART_TEXT, SceneManager.start_day], [MENU_TEXT, SceneManager.return_to_menu]]:
		var button: Button = Button.new()
		button.text = spec[0]
		button.add_theme_font_size_override("font_size", 12)
		button.focus_mode = Control.FOCUS_NONE  # Keys keep their meaning; the buttons are for the mouse.
		button.pressed.connect(spec[1])
		row.add_child(button)
	_hint_label.get_parent().add_child(row)


## Top-right card: how the stats ended and what happened during the day.
func _add_summary(summary: RunSummary) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StatFormatter.panel_style())
	panel.custom_minimum_size.x = SUMMARY_WIDTH
	panel.position = Vector2(BaseLevel.SCREEN_SIZE.x - SUMMARY_WIDTH - 8.0, 8.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = SUMMARY_TITLE
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(title)
	var stats: HBoxContainer = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	var values: Dictionary = {
		StatDefinition.Type.MONEY: summary.money,
		StatDefinition.Type.ENERGY: summary.energy,
		StatDefinition.Type.TIME: summary.time,
	}
	for type: StatDefinition.Type in values:
		var icon: TextureRect = TextureRect.new()
		icon.texture = StatsManager.get_definition(type).icon
		icon.custom_minimum_size = Vector2(14.0, 14.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stats.add_child(icon)
		var value: Label = Label.new()
		value.text = StatFormatter.format_value(type, values[type])
		value.add_theme_font_size_override("font_size", 12)
		stats.add_child(value)
	box.add_child(stats)
	var counts: Label = Label.new()
	counts.text = SUMMARY_FORMAT % [summary.decisions.size(), summary.events.size(), summary.hostile_hits,
		summary.risks_taken, summary.risks_lost]
	counts.add_theme_font_size_override("font_size", 11)
	box.add_child(counts)
	for line: String in summary.decisions:
		var decision: Label = Label.new()
		decision.text = "• " + line
		decision.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		decision.add_theme_font_size_override("font_size", 10)
		decision.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		box.add_child(decision)
	add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if (Time.get_ticks_msec() - _opened_at_ms) / 1000.0 < INPUT_DELAY_SECONDS:
		return
	if event.is_action_pressed(InputActions.INTERACT):
		if _is_revealing():
			_skip_reveal()
		else:
			SceneManager.start_day()
	elif event.is_action_pressed(InputActions.PAUSE):
		SceneManager.return_to_menu()


func _pick_ending() -> EndingDefinition:
	var result: DayResult = SceneManager.last_result
	var ending: EndingDefinition
	if result != null:
		ending = EndingResolver.resolve(RunLog.build_summary(result), CATALOG)
	elif not preview_ending_id.is_empty():
		ending = CATALOG.find(preview_ending_id)
	else:
		push_warning("EndingScreen: no finished day and no preview id; showing the first ending.")
		ending = CATALOG.endings[0]
	assert(ending != null, "EndingScreen: ending not found.")
	return ending


func _start_reveal(character_count: int) -> void:
	_text_label.visible_ratio = 0.0
	var duration: float = minf(character_count * REVEAL_SECONDS_PER_CHARACTER, MAX_REVEAL_SECONDS)
	_reveal_tween = create_tween()
	_reveal_tween.tween_interval(REVEAL_DELAY_SECONDS)
	_reveal_tween.tween_property(_text_label, "visible_ratio", 1.0, duration)


func _is_revealing() -> bool:
	return _reveal_tween != null and _reveal_tween.is_running()


func _skip_reveal() -> void:
	_reveal_tween.kill()
	_text_label.visible_ratio = 1.0
