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


func _ready() -> void:
	assert(definition != null, "StatIndicator: definition is not assigned.")
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


func _show_popup(change: float) -> void:
	_delta_label.text = StatFormatter.format_change(definition.type, change)
	_delta_label.add_theme_color_override("font_color", GAIN_COLOR if change > 0.0 else LOSS_COLOR)
	if _popup_tween != null:
		_popup_tween.kill()
	_delta_label.modulate.a = 1.0
	_popup_tween = create_tween()
	_popup_tween.tween_interval(POPUP_HOLD_SECONDS)
	_popup_tween.tween_property(_delta_label, "modulate:a", 0.0, POPUP_FADE_SECONDS)
