extends Node
## Autoload. Achievements: one per ending plus a few for how the day was played. Unlocked ones are
## saved in user://achievements.cfg, so they last between sessions (replayability).
## They unlock the moment they are earned: Apostador on the third risk won, the ending ones when the
## day finishes (before the fade and the victory memory, not on the ending screen). The popup is drawn
## by this node, above everything, one achievement after another.

signal unlocked(id: String)

const SAVE_PATH: String = "user://achievements.cfg"
const CATALOG: EndingCatalog = preload("res://data/endings/ending_catalog.tres")
const POPUP_LAYER: int = 110  # Above the scene transition (100).
const POPUP_SECONDS: float = 2.8
const POPUP_IN_SECONDS: float = 0.35
const POPUP_OUT_SECONDS: float = 0.4
const POPUP_WIDTH: float = 330.0
const POPUP_TOP: float = 36.0
const GOLD: Color = Color(1.0, 0.82, 0.25)
## Outcomes that need more than the ending.
const UNTOUCHABLE: String = "untouchable"
const GAMBLER: String = "gambler"
const COLLECTOR: String = "collector"
const GAMBLER_RISKS: int = 3
## Player-visible texts (Spanish). id -> [title, how to get it]. Ending ids are "ending_" + ending id.
const DEFINITIONS: Dictionary = {
	"ending_V-01": ["Día redondo", "Llega a casa con plata, energía y tiempo de sobra."],
	"ending_V-02": ["Llegar es ganar", "Llega a casa a duras penas."],
	"ending_V-03": ["Nadie sale adelante solo", "Ayuda a alguien, o deja que te ayuden, y llega a casa."],
	"ending_V-04": ["Contra reloj", "Entrega las carpetas de El Marcador con 15 s de sobra."],
	"ending_V-05": ["Ahorrador", "Llega a casa con $40.000 o más."],
	"ending_V-06": ["Noche de Gran Trancón", "Date un gusto con el vendedor ambulante y llega a casa."],
	"ending_D-01": ["Bolsillo vacío", "Quédate sin plata."],
	"ending_D-02": ["Fundido", "Quédate sin energía."],
	"ending_D-03": ["Se fue el día", "Quédate sin tiempo."],
	"ending_D-04": ["Descuido", "Que un robo te deje sin plata."],
	"ending_D-05": ["El reloj no perdona", "Pierde contra El Marcador."],
	UNTOUCHABLE: ["Intocable", "Llega a casa sin que nada ni nadie te golpee."],
	GAMBLER: ["Apostador", "Sal bien librado de 3 riesgos en un mismo día."],
	COLLECTOR: ["Coleccionista", "Descubre todos los finales."],
}
const POPUP_TITLE: String = "¡Logro desbloqueado!"

## Where they are saved. The self-test points it to its own file so it never touches the player's.
var save_path: String = SAVE_PATH
var _unlocked: Dictionary = {}  # id -> date text
var _risks_won_today: int = 0
## Achievements waiting for their popup, and whether one is on screen.
var _pending_popups: Array[String] = []
var _popup_showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for id: String in config.get_section_keys("unlocked") if config.has_section("unlocked") else []:
			_unlocked[id] = config.get_value("unlocked", id, "")
	EventBus.day_step_started.connect(_on_day_step_started)
	EventBus.risk_drawn.connect(_on_risk_drawn)
	EventBus.day_finished.connect(_on_day_finished)


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


func unlocked_date(id: String) -> String:
	return _unlocked.get(id, "")


func _on_day_step_started(step: DayStep) -> void:
	if step.stage == DayStep.Stage.HOME and step.number_in_stage == 1:
		_risks_won_today = 0


func _on_risk_drawn(_option: DecisionOption, happened: bool, _draw: float) -> void:
	if not happened:
		_risks_won_today += 1
		if _risks_won_today >= GAMBLER_RISKS:
			unlock(GAMBLER)


## The ending is decided here with the same rules as the ending screen, so its achievement shows up
## at once, over the "¡Llegaste a casa!" fade. Deferred to the end of the frame: a theft that empties
## the money ends the day before the hit or event that tells RunLog it was a theft (D-04, not D-01).
func _on_day_finished(result: DayResult) -> void:
	_resolve_day.call_deferred(result)


func _resolve_day(result: DayResult) -> void:
	var summary: RunSummary = RunLog.build_summary(result)
	on_day_ended(EndingResolver.resolve(summary, CATALOG).id, summary)


## Unlocks what the end of the day gives: the ending, Intocable, Apostador (if missed) and Coleccionista.
func on_day_ended(ending_id: String, summary: RunSummary) -> void:
	unlock("ending_" + ending_id)
	if summary.is_victory and summary.hostile_hits == 0:
		unlock(UNTOUCHABLE)
	if summary.risks_taken - summary.risks_lost >= GAMBLER_RISKS:
		unlock(GAMBLER)
	var all_endings: bool = true
	for id: String in DEFINITIONS:
		if id.begins_with("ending_") and not is_unlocked(id):
			all_endings = false
	if all_endings:
		unlock(COLLECTOR)


func unlock(id: String) -> void:
	if is_unlocked(id) or not DEFINITIONS.has(id):
		return
	_unlocked[id] = Time.get_date_string_from_system()
	_save()
	unlocked.emit(id)
	_pending_popups.append(id)
	if not _popup_showing:
		_show_next_popup()


## Tests: forgets every achievement and empties the save file at save_path.
func reset() -> void:
	_unlocked.clear()
	_save()


func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	for id: String in _unlocked:
		config.set_value("unlocked", id, _unlocked[id])
	var error: Error = config.save(save_path)
	if error != OK:
		push_warning("Achievements: could not save %s (error %d)." % [save_path, error])


## A banner at the top center that pops in (bounce), stays POPUP_SECONDS and fades out; several
## achievements show one after another.
func _show_next_popup() -> void:
	if _pending_popups.is_empty():
		_popup_showing = false
		return
	_popup_showing = true
	var id: String = _pending_popups.pop_front()
	AudioManager.play_sfx(&"decision_good")
	AudioManager.play_sfx(&"coin", 1.2)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = POPUP_LAYER
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.95)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = POPUP_WIDTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var star: Control = Control.new()
	star.custom_minimum_size = Vector2(36.0, 36.0)
	star.draw.connect(_draw_star.bind(star))
	row.add_child(star)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	for spec: Array in [[POPUP_TITLE, GOLD, 12], [DEFINITIONS[id][0], Color.WHITE, 20], [DEFINITIONS[id][1], Color(0.75, 0.75, 0.8), 11]]:
		var label: Label = Label.new()
		label.text = spec[0]
		label.add_theme_color_override("font_color", spec[1])
		label.add_theme_font_size_override("font_size", spec[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	layer.add_child(panel)
	await get_tree().process_frame  # The panel knows its size now.
	panel.position = Vector2((BaseLevel.SCREEN_SIZE.x - panel.size.x) / 2.0, POPUP_TOP)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.3, 0.3)
	var tween: Tween = layer.create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, POPUP_IN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(POPUP_SECONDS)
	tween.tween_property(panel, "position:y", POPUP_TOP - 20.0, POPUP_OUT_SECONDS)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, POPUP_OUT_SECONDS)
	tween.tween_callback(layer.queue_free)
	tween.tween_callback(_show_next_popup)


func _draw_star(control: Control) -> void:
	var center: Vector2 = control.size / 2.0
	var points: PackedVector2Array = []
	for i: int in 10:
		var radius: float = 17.0 if i % 2 == 0 else 7.0
		var angle: float = -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	control.draw_colored_polygon(points, GOLD)
	points.append(points[0])
	control.draw_polyline(points, Color(0.55, 0.38, 0.05), 1.5)
