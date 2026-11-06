extends CanvasLayer
## Debug-only readout of the stats and the fatigue factor.

const DRAW_LAYER: int = 80
const MARGIN: Vector2 = Vector2(4.0, 336.0)
const OUTLINE_SIZE: int = 2

var _label: Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = DRAW_LAYER
	_label = Label.new()
	_label.position = MARGIN
	_label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)


func _process(_delta: float) -> void:
	_label.text = "Money %.1f | Energy %.1f | Time %.1f | Speed x%.2f" % [
		StatsManager.get_value(StatDefinition.Type.MONEY),
		StatsManager.get_value(StatDefinition.Type.ENERGY),
		StatsManager.get_value(StatDefinition.Type.TIME),
		Simulation.speed_factor(),
	]
