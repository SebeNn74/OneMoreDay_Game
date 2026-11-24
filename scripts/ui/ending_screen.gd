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
	_start_reveal(ending.text.length())


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
