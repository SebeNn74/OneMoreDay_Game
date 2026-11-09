class_name PhoneNotification
extends CanvasLayer
## Phone-style message box. Shows what EventBus.notification_requested asks for,
## locks the game (DIALOG state) while open, and closes with the interact action.

const DRAW_LAYER: int = 20  # Above the HUD (10), below pause (90) and transitions (100).

@onready var _content: Control = %Content
@onready var _message_label: Label = %MessageLabel

var _opened_frame: int = -1


func _ready() -> void:
	layer = DRAW_LAYER
	_content.visible = false
	EventBus.notification_requested.connect(_on_notification_requested)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the key press that opened the notification (same frame).
	if not _content.visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(InputActions.INTERACT):
		get_viewport().set_input_as_handled()
		_close()


func _on_notification_requested(text: String) -> void:
	_message_label.text = text
	_content.visible = true
	_opened_frame = Engine.get_process_frames()
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)


func _close() -> void:
	_content.visible = false
	if GameManager.current_state == GameState.Type.DIALOG:
		GameManager.change_state(GameState.Type.PLAYING)
	EventBus.notification_closed.emit()
