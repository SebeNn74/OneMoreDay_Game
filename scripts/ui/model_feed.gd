class_name ModelFeed
extends CanvasLayer
## On-screen panel with the five simulation models, one row each. A row lights up when its
## model acts (Simulation.model_used) and keeps the last thing it did. The dynamics row also
## shows the live flows (energy and time per second) and the fatigue speed factor.
## M shows or hides it (the choice lasts across levels). Meant for the video and the exposition.

const DRAW_LAYER: int = 15  # Above the HUD (10), below dialogs (20).
const TOGGLE_KEY: Key = KEY_M
const PANEL_WIDTH: float = 290.0
const PANEL_TOP: float = 22.0  # Just below the HUD row.
const MARGIN: float = 4.0
const FONT_SIZE: int = 12
const NAME_WIDTH: float = 66.0
const DOT_SIZE: Vector2 = Vector2(6.0, 6.0)
## A row stays lit this long after its model acts, then fades to the idle look.
const HIGHLIGHT_SECONDS: float = 2.5
const FADE_SECONDS: float = 0.6
const IDLE_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.75)
const ACTIVE_MODULATE: Color = Color.WHITE
const PANEL_COLOR: Color = Color(0.0, 0.0, 0.0, 0.72)
const IDLE_TEXT: String = "sin actividad aún"
## Flows are the small per-frame stat changes; hits, events and items are bigger pulses.
const FLOW_CHANGE_LIMIT: float = 1.0
const FLOW_WINDOW_SECONDS: float = 0.5
const FLOW_FORMAT: String = "E %+.2f/s · T %+.2f/s · velocidad x%.2f"
const NO_FLOW_TEXT: String = "quieto: sin flujos · velocidad x%.2f"

## Shared by every level, so hiding the panel once keeps it hidden.
static var shown: bool = true
## Last report of each model, so a new level keeps showing what already happened today.
static var last_details: Dictionary = {}

var _rows: Dictionary = {}  # model -> {row, detail, tween}
var _flow_energy: float = 0.0
var _flow_time: float = 0.0
var _flow_elapsed: float = 0.0
## While > 0 the dynamics row keeps showing its last report instead of the live flows.
var _flow_hold: float = 0.0
var _panel: PanelContainer


func _ready() -> void:
	layer = DRAW_LAYER
	var step: DayStep = SceneManager.get_current_step()
	if step != null and step.stage == DayStep.Stage.HOME:
		last_details.clear()  # A new day starts at home.
	_build()
	visible = shown
	Simulation.model_used.connect(_on_model_used)
	EventBus.stat_changed.connect(_on_stat_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		shown = not shown
		visible = shown
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if GameManager.current_state != GameState.Type.PLAYING:
		return
	if _flow_hold > 0.0:
		_flow_hold -= delta
		_flow_energy = 0.0
		_flow_time = 0.0
		_flow_elapsed = 0.0
		return
	_flow_elapsed += delta
	if _flow_elapsed < FLOW_WINDOW_SECONDS:
		return
	var detail: Label = _rows[Simulation.MODEL_DYNAMICS].detail
	if is_zero_approx(_flow_energy) and is_zero_approx(_flow_time):
		detail.text = NO_FLOW_TEXT % Simulation.speed_factor()
	else:
		detail.text = FLOW_FORMAT % [
			_flow_energy / _flow_elapsed, _flow_time / _flow_elapsed, Simulation.speed_factor()]
	_flow_energy = 0.0
	_flow_time = 0.0
	_flow_elapsed = 0.0


func _build() -> void:
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(2)
	style.set_content_margin_all(MARGIN)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.position = Vector2(BaseLevel.SCREEN_SIZE.x - PANEL_WIDTH - MARGIN, PANEL_TOP)
	add_child(_panel)

	var rows_box: VBoxContainer = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 0)
	rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rows_box)

	# Model -> [short name shown in the row, color].
	var models: Dictionary = {
		Simulation.MODEL_QUEUE: ["Colas", Color(0.45, 0.7, 1.0)],
		Simulation.MODEL_RANDOM_WALK: ["Caminata", Color(0.5, 0.9, 0.5)],
		Simulation.MODEL_MONTE_CARLO: ["Monte Carlo", Color(0.8, 0.6, 1.0)],
		Simulation.MODEL_AGENTS: ["Agentes", Color(1.0, 0.55, 0.4)],
		Simulation.MODEL_DYNAMICS: ["Dinámica", Color(1.0, 0.85, 0.35)],
	}
	for model: StringName in models:
		_rows[model] = _build_row(rows_box, models[model][0], models[model][1])
		if last_details.has(model):
			_rows[model].detail.text = last_details[model]


func _build_row(parent: VBoxContainer, short_name: String, color: Color) -> Dictionary:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate = IDLE_MODULATE
	parent.add_child(row)

	var dot: ColorRect = ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = DOT_SIZE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var name_label: Label = _make_label(short_name, color)
	name_label.custom_minimum_size.x = NAME_WIDTH
	row.add_child(name_label)

	var detail: Label = _make_label(IDLE_TEXT, Color.WHITE)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(detail)
	return {"row": row, "detail": detail, "tween": null}


func _make_label(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_model_used(model: StringName, detail: String) -> void:
	if not _rows.has(model):
		return
	var entry: Dictionary = _rows[model]
	entry.detail.text = detail
	last_details[model] = detail
	if model == Simulation.MODEL_DYNAMICS:
		_flow_hold = HIGHLIGHT_SECONDS  # Let the report be read before the live flows return.
	var row: HBoxContainer = entry.row
	if entry.tween != null:
		(entry.tween as Tween).kill()
	row.modulate = ACTIVE_MODULATE
	var tween: Tween = create_tween()
	tween.tween_interval(HIGHLIGHT_SECONDS)
	tween.tween_property(row, "modulate", IDLE_MODULATE, FADE_SECONDS)
	entry.tween = tween


func _on_stat_changed(type: StatDefinition.Type, _new_value: float, change: float) -> void:
	if absf(change) >= FLOW_CHANGE_LIMIT:
		return
	match type:
		StatDefinition.Type.ENERGY:
			_flow_energy += change
		StatDefinition.Type.TIME:
			_flow_time += change

