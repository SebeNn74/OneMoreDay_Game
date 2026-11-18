class_name ClockHud
extends CanvasLayer
## Big countdown clock and folder counter of a challenge. Only listens to EventBus.

const DRAW_LAYER: int = 12
const URGENT_SECONDS: float = 10.0
const NORMAL_COLOR: Color = Color.WHITE
const URGENT_COLOR: Color = Color(0.95, 0.35, 0.3)
const DONE_COLOR: Color = Color(0.45, 0.85, 0.45)
const PROGRESS_FORMAT: String = "Carpetas %d/%d"
const DELIVERED_TEXT: String = "¡Entregado!"

@onready var _clock_label: Label = %ClockLabel
@onready var _progress_label: Label = %ProgressLabel

var _is_finished: bool = false


func _ready() -> void:
	layer = DRAW_LAYER
	EventBus.challenge_clock_changed.connect(_on_clock_changed)
	EventBus.challenge_progress_changed.connect(_on_progress_changed)
	EventBus.challenge_finished.connect(_on_finished)


func _on_clock_changed(seconds_left: float) -> void:
	if _is_finished:
		return
	_clock_label.text = str(ceili(seconds_left))
	var color: Color = URGENT_COLOR if seconds_left <= URGENT_SECONDS else NORMAL_COLOR
	_clock_label.add_theme_color_override("font_color", color)


func _on_progress_changed(collected: int, total: int) -> void:
	_progress_label.text = PROGRESS_FORMAT % [collected, total]


func _on_finished(is_success: bool, _seconds_left: float) -> void:
	_is_finished = true
	if is_success:
		_clock_label.text = DELIVERED_TEXT
		_clock_label.add_theme_color_override("font_color", DONE_COLOR)
