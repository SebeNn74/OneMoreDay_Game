class_name StatIndicator
extends HBoxContainer
## HUD readout of one stat: text, optional bar and a short popup on changes.
## Only listens to EventBus: it knows nothing about who changes the stat.

## Changes smaller than this (continuous flows) update the readout but show no popup.
const MIN_POPUP_CHANGE: float = 1.0
const POPUP_HOLD_SECONDS: float = 1.0
const POPUP_FADE_SECONDS: float = 0.5
const GAIN_COLOR: Color = Color(0.45, 0.85, 0.45)
const LOSS_COLOR: Color = Color(0.90, 0.35, 0.30)

@export var definition: StatDefinition

@onready var _icon: TextureRect = %Icon
@onready var _value_label: Label = %ValueLabel
@onready var _bar: ProgressBar = %Bar
@onready var _delta_label: Label = %DeltaLabel

var _popup_tween: Tween
var _panel_style: StyleBoxFlat
var _warning_tween: Tween
var _is_low: bool = false

## Bar color per stat, and below which value it warns (red, blinking).
const BAR_COLORS: Dictionary = {
	StatDefinition.Type.ENERGY: Color(0.98, 0.8, 0.25),
	StatDefinition.Type.TIME: Color(0.4, 0.75, 1.0),
}
const LOW_LIMITS: Dictionary = {
	StatDefinition.Type.MONEY: 5.0,
	StatDefinition.Type.ENERGY: 25.0,
	StatDefinition.Type.TIME: 20.0,
}
const LOW_COLOR: Color = Color(1.0, 0.35, 0.3)
const PANEL_PADDING: Vector2 = Vector2(5.0, 3.0)


func _ready() -> void:
	assert(definition != null, "StatIndicator: definition is not assigned.")
	_style()
	_icon.texture = definition.icon
	_icon.visible = definition.icon != null
	_bar.visible = definition.has_max_value
	_bar.max_value = definition.max_value
	_bar.show_percentage = false
	_delta_label.modulate.a = 0.0  # Keeps its space so the layout does not jump.
	EventBus.stat_changed.connect(_on_stat_changed)
	_refresh(StatsManager.get_value(definition.type))


func _on_stat_changed(type: StatDefinition.Type, new_value: float, change: float) -> void:
	if type != definition.type:
		return
	_refresh(new_value)
	if absf(change) >= MIN_POPUP_CHANGE:
		_show_popup(change)


func _refresh(value: float) -> void:
	_value_label.text = "%s %s" % [definition.display_name, StatFormatter.format_value(definition.type, value)]
	_bar.value = value
	_set_low(value <= LOW_LIMITS.get(definition.type, -INF))


## Dark rounded panel behind the readout and a colored bar, so the HUD reads over any background.
func _style() -> void:
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	_panel_style.set_corner_radius_all(3)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = BAR_COLORS.get(definition.type, Color.WHITE)
	fill.set_corner_radius_all(2)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(1.0, 1.0, 1.0, 0.18)
	background.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", background)
	_bar.custom_minimum_size = Vector2(90.0, 6.0)


func _draw() -> void:
	if _panel_style != null:
		draw_style_box(_panel_style, Rect2(-PANEL_PADDING, size - Vector2(_delta_label.size.x, 0.0) + PANEL_PADDING * 2.0))


func _set_low(is_low: bool) -> void:
	if is_low == _is_low:
		return
	_is_low = is_low
	if _warning_tween != null:
		_warning_tween.kill()
	_value_label.modulate = Color.WHITE
	if is_low:
		_value_label.add_theme_color_override("font_color", LOW_COLOR)
		_warning_tween = create_tween().set_loops()
		_warning_tween.tween_property(_value_label, "modulate:a", 0.35, 0.4)
		_warning_tween.tween_property(_value_label, "modulate:a", 1.0, 0.4)
	else:
		_value_label.remove_theme_color_override("font_color")


func _show_popup(change: float) -> void:
	_delta_label.text = StatFormatter.format_change(definition.type, change)
	_delta_label.add_theme_color_override("font_color", GAIN_COLOR if change > 0.0 else LOSS_COLOR)
	if _popup_tween != null:
		_popup_tween.kill()
	_delta_label.modulate.a = 1.0
	_popup_tween = create_tween()
	_popup_tween.tween_interval(POPUP_HOLD_SECONDS)
	_popup_tween.tween_property(_delta_label, "modulate:a", 0.0, POPUP_FADE_SECONDS)
