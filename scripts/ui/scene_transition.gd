class_name SceneTransition
extends CanvasLayer
## Full-screen fade to black. Awaitable: await fade_out() / await fade_in().
## An optional caption ("¡Tramo superado!", "Un día más") shows on the black screen.

const FADE_DURATION: float = 0.35
const DRAW_LAYER: int = 100

@onready var _overlay: ColorRect = $Overlay

var _caption: Label

var _tween: Tween


func _ready() -> void:
	layer = DRAW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps fading if the tree gets paused.
	_overlay.color = Color.BLACK
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.modulate.a = 0.0
	_caption = Label.new()  # Child of the overlay: it fades with it.
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	_overlay.add_child(_caption)


## Text for the next black screen ("" = plain fade).
func set_caption(text: String) -> void:
	_caption.text = text


func fade_out() -> void:
	await _fade_to(1.0)


func fade_in() -> void:
	await _fade_to(0.0)


func _fade_to(target_alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", target_alpha, FADE_DURATION)
	await _tween.finished
