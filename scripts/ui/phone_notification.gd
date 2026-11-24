class_name PhoneNotification
extends CanvasLayer
## Phone-style message box. Shows what EventBus.notification_requested asks for,
## locks the game (DIALOG state) while open, and closes with the interact action.
## EventBus.toast_requested shows the same box as a toast: no lock, no key, it fades on its own.

const DRAW_LAYER: int = 20  # Above the HUD (10), below pause (90) and transitions (100).

@onready var _content: Control = %Content
@onready var _message_label: Label = %MessageLabel

var _opened_frame: int = -1
var _is_toast: bool = false
var _toast_tween: Tween

const TOAST_SECONDS: float = 4.0
const TOAST_FADE_SECONDS: float = 0.6

@onready var _hint_label: Label = $Content/Margin/Panel/Padding/VBox/HintLabel


func _ready() -> void:
	layer = DRAW_LAYER
	_content.visible = false
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.toast_requested.connect(_on_toast_requested)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the key press that opened the notification (same frame).
	if not _content.visible or _is_toast or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(InputActions.INTERACT):
		get_viewport().set_input_as_handled()
		_close()


func _on_notification_requested(text: String) -> void:
	_stop_toast()
	_message_label.text = text
	_content.visible = true
	_opened_frame = Engine.get_process_frames()
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)


func _on_toast_requested(text: String) -> void:
	if _content.visible and not _is_toast:
		return  # A message that needs reading is open: it wins.
	_stop_toast()
	_is_toast = true
	_message_label.text = text
	_hint_label.visible = false
	_content.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_content, "modulate:a", 0.0, TOAST_FADE_SECONDS)
	_toast_tween.tween_callback(_stop_toast)


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
