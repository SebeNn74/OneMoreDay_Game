class_name InteractionPrompt
extends Node2D
## Floating "[E] action" hint above the interactable in focus.

const KEY_LABEL: String = "E"
const DRAW_ORDER: int = 100

@onready var _label: Label = $Label


func _ready() -> void:
	top_level = true  # Ignore the player's position and scale.
	z_index = DRAW_ORDER
	hide()


func on_focus_changed(target: Interactable) -> void:
	if target == null:
		hide()
		return

	_label.text = _build_text(target.action_text)
	_label.reset_size()
	_label.position = -_label.size / 2.0  # Center the text on the node.
	global_position = target.global_position + target.prompt_offset
	show()


func _build_text(action_text: String) -> String:
	if action_text.is_empty():
		return "[%s]" % KEY_LABEL
	return "[%s] %s" % [KEY_LABEL, action_text]
