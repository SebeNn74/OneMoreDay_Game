class_name ReportSequenceMinigame
extends Minigame
## "Ordena el informe": repeat key sequences (W A S D or the arrows) as fast as you can.
## Each finished sequence is a page; each wrong key restarts the sequence and tires you.

const NPC_FRAMES: SpriteFrames = preload("res://assets/sprites/npcs/npc_sprite_frames.tres")
const ITEM_FRAMES: SpriteFrames = preload("res://assets/sprites/items/items_sprite_frames.tres")
const KEYS: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]
const KEY_LABELS: PackedStringArray = ["W", "A", "S", "D"]
const START_LENGTH: int = 4
const MAX_LENGTH: int = 7
const MONEY_PER_PAGE: float = 1.0
const MAX_PAGES_PAID: int = 4
const ENERGY_PER_MISTAKE: float = -1.0
const MAX_MISTAKES_CHARGED: int = 5
const LETTER_SIZE: int = 40
const LETTER_GAP: float = 56.0
const ROW_Y: float = 250.0

var _sequence: Array[int] = []
var _typed: int = 0
var _pages: int = 0
var _mistakes: int = 0
var _flash: float = 0.0
var _canvas: Control
var _rng: Lcg


func _init() -> void:
	title = "Ordena el informe"
	instructions = "Ayúdale a tu compañero a ordenar el informe: repite cada secuencia de teclas (W A S D o las flechas). Cada hoja terminada te paga más; cada error te cansa."
	duration_seconds = 12.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	stage.add_child(_canvas)
	var people: Node2D = Node2D.new()
	stage.add_child(people)
	people.add_child(_sprite(NPC_FRAMES, &"coworker", Vector2(470.0, 196.0), 96.0))
	for i: int in 3:
		people.add_child(_sprite(ITEM_FRAMES, &"folder", Vector2(150.0 + i * 6.0, 196.0 - i * 6.0), 36.0))
	_new_sequence()


func _new_sequence() -> void:
	_sequence.clear()
	for i: int in mini(START_LENGTH + _pages, MAX_LENGTH):
		_sequence.append(_rng.index(KEYS.size()))
	_typed = 0


func _on_input(event: InputEvent) -> void:
	if not is_playing():
		return
	for k: int in KEYS.size():
		if event.is_action_pressed(KEYS[k]):
			if k == _sequence[_typed]:
				_typed += 1
				AudioManager.play_sfx(&"ui_move", 1.0 + _typed * 0.08)
				if _typed >= _sequence.size():
					_pages += 1
					_big_label.text = "¡Hoja lista!"
					_phase_time = 0.0
					AudioManager.play_sfx(&"coin")
					_new_sequence()
			else:
				_mistakes += 1
				_typed = 0
				_flash = 0.35
				AudioManager.play_sfx(&"hit")
			_canvas.queue_redraw()
			return


func _play(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_canvas.queue_redraw()


func _result() -> Dictionary:
	var paid: int = mini(_pages, MAX_PAGES_PAID)
	var charged: int = mini(_mistakes, MAX_MISTAKES_CHARGED)
	var summary: String = "Ordenaste %d %s (%d %s)" % [
		_pages, "hoja" if _pages == 1 else "hojas", _mistakes, "error" if _mistakes == 1 else "errores"]
	return {"money": MONEY_PER_PAGE * paid, "energy": ENERGY_PER_MISTAKE * charged, "time": 0.0, "summary": summary}


func _draw_scene() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("6f7f94"))  # Office wall.
	c.draw_rect(Rect2(0.0, 196.0, SCREEN.x, SCREEN.y - 196.0), Color("3d4a5c"))  # Carpet.
	c.draw_rect(Rect2(90.0, 196.0, 300.0, 18.0), Color("9a6b4f"))  # Desk.
	c.draw_rect(Rect2(250.0, 140.0, 70.0, 50.0), Color("2c3e50"))  # Monitor.
	c.draw_rect(Rect2(255.0, 145.0, 60.0, 38.0), Color("5dade2"))
	c.draw_rect(Rect2(280.0, 190.0, 10.0, 8.0), Color("2c3e50"))
	if not is_playing():
		return
	var font: Font = c.get_theme_default_font()
	var start_x: float = (SCREEN.x - LETTER_GAP * (_sequence.size() - 1)) / 2.0
	for i: int in _sequence.size():
		var color: Color = Color("3fae5a") if i < _typed else Color.WHITE
		if _flash > 0.0:
			color = Color("e74c3c")
		var x: float = start_x + i * LETTER_GAP
		c.draw_rect(Rect2(x - 22.0, ROW_Y - 40.0, 44.0, 50.0), Color(0.0, 0.0, 0.0, 0.6))
		c.draw_string(font, Vector2(x - 12.0, ROW_Y), KEY_LABELS[_sequence[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, color)
	c.draw_string(font, Vector2(20.0, 340.0), "Hojas: %d   Errores: %d" % [_pages, _mistakes], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
