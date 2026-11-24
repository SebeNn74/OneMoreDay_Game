class_name PhoneNotification
extends CanvasLayer
## Phone-style message box. Shows what EventBus.notification_requested asks for,
## locks the game (DIALOG state) while open, and closes with the interact action.
## EventBus.toast_requested shows the same box as a toast: no lock, no key, it fades on its own.
## A random event (EventBus.game_event_triggered) adds a title and one chip per stat it changes.

const DRAW_LAYER: int = 20  # Above the HUD (10), below pause (90) and transitions (100).

@onready var _content: Control = %Content
@onready var _message_label: Label = %MessageLabel

var _opened_frame: int = -1
var _is_toast: bool = false
var _toast_tween: Tween

const TOAST_SECONDS: float = 4.0
const EVENT_TOAST_SECONDS: float = 5.5
const TOAST_FADE_SECONDS: float = 0.6
const EVENT_TITLE: String = "Evento al azar (Markov-Monte Carlo)"
const GAIN_COLOR: Color = Color(0.45, 0.85, 0.45)
const LOSS_COLOR: Color = Color(0.95, 0.45, 0.40)
const ACCENT: Color = Color(1.0, 0.85, 0.3)

var _title_label: Label
var _effects_box: HBoxContainer

@onready var _hint_label: Label = $Content/Margin/Panel/Padding/VBox/HintLabel


func _ready() -> void:
	layer = DRAW_LAYER
	_content.visible = false
	$Content/Margin/Panel.add_theme_stylebox_override("panel", StatFormatter.panel_style())
	var box: VBoxContainer = $Content/Margin/Panel/Padding/VBox
	_title_label = Label.new()
	_title_label.text = EVENT_TITLE
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", ACCENT)
	_title_label.visible = false
	box.add_child(_title_label)
	box.move_child(_title_label, 0)
	_effects_box = HBoxContainer.new()
	_effects_box.add_theme_constant_override("separation", 14)
	box.add_child(_effects_box)
	box.move_child(_effects_box, _hint_label.get_index())
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.toast_requested.connect(_on_toast_requested)
	EventBus.game_event_triggered.connect(_on_game_event)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the key press that opened the notification (same frame).
	if not _content.visible or _is_toast or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(InputActions.INTERACT):
		get_viewport().set_input_as_handled()
		_close()


func _on_notification_requested(text: String) -> void:
	_stop_toast()
	_clear_effects()
	_message_label.text = text
	_content.visible = true
	_opened_frame = Engine.get_process_frames()
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)


func _on_toast_requested(text: String) -> void:
	if _content.visible and not _is_toast:
		return  # A message that needs reading is open: it wins.
	_stop_toast()
	_clear_effects()
	_is_toast = true
	_message_label.text = text
	_hint_label.visible = false
	_content.visible = true
	_start_fade(TOAST_SECONDS)


func _start_fade(seconds: float) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_content.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_content, "modulate:a", 0.0, TOAST_FADE_SECONDS)
	_toast_tween.tween_callback(_stop_toast)


## The event that was just shown: say which stats it changed, with their icons.
func _on_game_event(event: GameEvent) -> void:
	if not _content.visible or _message_label.text != event.text:
		return
	_title_label.visible = true
	var changes: Dictionary = {
		StatDefinition.Type.MONEY: event.money,
		StatDefinition.Type.ENERGY: event.energy,
		StatDefinition.Type.TIME: event.time,
	}
	for type: StatDefinition.Type in changes:
		var amount: float = changes[type]
		if is_zero_approx(amount):
			continue
		var chip: HBoxContainer = HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		var icon: TextureRect = TextureRect.new()
		icon.texture = StatsManager.get_definition(type).icon
		icon.custom_minimum_size = Vector2(16.0, 16.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.add_child(icon)
		var label: Label = Label.new()
		label.text = "%s %s" % [StatsManager.get_definition(type).display_name, StatFormatter.format_change(type, amount)]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", GAIN_COLOR if amount > 0.0 else LOSS_COLOR)
		chip.add_child(label)
		_effects_box.add_child(chip)
	if _is_toast:
		_start_fade(EVENT_TOAST_SECONDS)  # A bit longer, so the effects can be read.


func _clear_effects() -> void:
	_title_label.visible = false
	for child: Node in _effects_box.get_children():
		child.queue_free()


func _stop_toast() -> void:
	if _toast_tween != null:
		_toast_tween.kill()
		_toast_tween = null
	if _is_toast:
		_content.visible = false
	_is_toast = false
	_content.modulate.a = 1.0
	_hint_label.visible = true


func _close() -> void:
	_content.visible = false
	if GameManager.current_state == GameState.Type.DIALOG:
		GameManager.change_state(GameState.Type.PLAYING)
	EventBus.notification_closed.emit()
