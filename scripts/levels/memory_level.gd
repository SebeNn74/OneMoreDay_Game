class_name MemoryLevel
extends BaseLevel
## Victory (design doc 3.5): a short, warm memory at home where the player can walk around for a
## while. Reuses the home (memory.tscn inherits home_01.tscn) with warm light and memory texts on
## the objects. Ends when the time runs out or the player walks out the door; then the ending screen.

const DURATION_SECONDS: float = 25.0
const WARM_LIGHT: Color = Color(1.0, 0.86, 0.66)
const MUSIC_DELAY_SECONDS: float = 1.5  # Lets the victory jingle finish.
## Player-visible texts (Spanish).
const CAPTION: String = "Un recuerdo: el domingo en casa"
const COUNTDOWN_FORMAT: String = "Recorre la casa  ·  %d s  ·  sal por la puerta para terminar"
const MEMORY_LINES: Dictionary = {
	"Bed": ["Los domingos te quedabas acostado hasta tarde, oyendo la radio de la cocina."],
	"Fridge": ["Huele a sancocho. Tu mamá cocina para todos, como cada domingo."],
	"DeskPapers": ["Un dibujo de tu sobrino pegado en la pared: «para mi tío favorito»."],
	"TvRemote": ["El partido en la tele y toda la familia gritando el gol."],
	"Calendar": ["Hoy no hay recibos ni horarios. Solo domingo."],
	"Photos": ["Esta foto la tomaron hoy. Todos salieron riéndose."],
}

var _seconds_left: float = DURATION_SECONDS
var _countdown: Label
var _is_leaving: bool = false


func _ready() -> void:
	super()
	GameManager.change_state(GameState.Type.PLAYING)  # Walkable, though the day is over.
	var phone: Node = get_node_or_null("%Phone")
	if phone != null:
		phone.queue_free()  # No notifications in a memory.
	AudioManager.ring_phone(false)
	for node_name: String in MEMORY_LINES:
		var flavor: FlavorInteractable = get_node_or_null("World/Interactables/" + node_name) as FlavorInteractable
		if flavor != null:
			flavor.lines = PackedStringArray(MEMORY_LINES[node_name])
	$UI/Hud.hide()  # No resources to watch in a memory.
	var light: CanvasModulate = CanvasModulate.new()
	light.color = WARM_LIGHT
	add_child(light)
	_build_caption()
	get_tree().create_timer(MUSIC_DELAY_SECONDS).timeout.connect(AudioManager.play_music.bind(&"memory"))


func _process(delta: float) -> void:
	if GameManager.current_state != GameState.Type.PLAYING:
		return  # Reading a memory text or paused: the time waits.
	_seconds_left -= delta
	_countdown.text = COUNTDOWN_FORMAT % ceili(maxf(_seconds_left, 0.0))
	if _seconds_left <= 0.0:
		_leave()


func get_guide_target() -> Variant:
	return null  # Nothing to reach: just look around.


func _on_exit_reached() -> void:
	_leave()


func _leave() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	SceneManager.show_ending()


func _build_caption() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(0.0, 6.0)
	box.size = Vector2(SCREEN_SIZE.x, 0.0)
	layer.add_child(box)
	var title: Label = Label.new()
	title.text = CAPTION
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.05))
	box.add_child(title)
	_countdown = Label.new()
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.add_theme_font_size_override("font_size", 12)
	_countdown.add_theme_constant_override("outline_size", 3)
	_countdown.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.05))
	box.add_child(_countdown)
