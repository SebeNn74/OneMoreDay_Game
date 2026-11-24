extends Node
## Autoload. Achievements: one per ending plus a few for how the day was played. Unlocked ones are
## saved in user://achievements.cfg, so they last between sessions (replayability).
## EndingScreen calls on_day_ended(); this node shows the "logro desbloqueado" popup itself,
## because the ending screen has no level UI.

signal unlocked(id: String)

const SAVE_PATH: String = "user://achievements.cfg"
const POPUP_LAYER: int = 110  # Above the scene transition (100).
const POPUP_SECONDS: float = 3.0
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for id: String in config.get_section_keys("unlocked") if config.has_section("unlocked") else []:
			_unlocked[id] = config.get_value("unlocked", id, "")


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


func unlocked_date(id: String) -> String:
	return _unlocked.get(id, "")


## Called once by the ending screen with the ending shown and the summary of the day.
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
	_show_popup(DEFINITIONS[id][0])


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


## Popups stack downwards when several achievements unlock together.
func _show_popup(title: String) -> void:
	AudioManager.play_sfx(&"buff")
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = POPUP_LAYER
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StatFormatter.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	for spec: Array in [[POPUP_TITLE, Color(1.0, 0.85, 0.3), 12], [title, Color.WHITE, 16]]:
		var label: Label = Label.new()
		label.text = spec[0]
		label.add_theme_color_override("font_color", spec[1])
		label.add_theme_font_size_override("font_size", spec[2])
		box.add_child(label)
	layer.add_child(panel)
	var stacked: int = get_child_count() - 1
	panel.position = Vector2(8.0, 8.0 + stacked * 44.0)
	var tween: Tween = layer.create_tween()
	tween.tween_interval(POPUP_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)
