class_name TintoTimingMinigame
extends Minigame
## "Sirve el tinto": three timing rounds (pour, sugar, hand over). A needle bounces along a bar;
## press E when it is inside the zone. Each round is faster and the zone smaller.

const NPC_FRAMES: SpriteFrames = preload("res://assets/sprites/npcs/npc_sprite_frames.tres")
const ITEM_FRAMES: SpriteFrames = preload("res://assets/sprites/items/items_sprite_frames.tres")
const ROUND_NAMES: PackedStringArray = ["Servir el tinto", "Echarle azúcar", "Entregarlo sin regar"]
const NEEDLE_SPEEDS: Array[float] = [230.0, 320.0, 410.0]
const ZONE_WIDTHS: Array[float] = [60.0, 46.0, 34.0]
const BAR_WIDTH: float = 320.0
const BAR_Y: float = 268.0
## Energy on top of the option's own effect, by rounds hit (0..3).
const ENERGY_BY_HITS: Array[float] = [-3.0, 0.0, 3.0, 6.0]
const PAUSE_SECONDS: float = 0.7

var _round: int = 0
var _hits: int = 0
var _needle: float = 0.0
var _direction: float = 1.0
var _zone_start: float = 0.0
var _pause: float = 0.0
var _canvas: Control
var _cup: AnimatedSprite2D
var _rng: Lcg


func _init() -> void:
	title = "Sirve el tinto"
	instructions = "La vendedora te deja servir tu tinto. Presiona E cuando la aguja esté en la zona verde: tres veces, cada vez más rápido. Bien servido te da más energía; si lo riegas, menos."
	duration_seconds = 15.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	stage.add_child(_canvas)
	var people: Node2D = Node2D.new()
	stage.add_child(people)
	people.add_child(_sprite(NPC_FRAMES, &"coffee_vendor", Vector2(320.0, 170.0), 96.0))
	_cup = _sprite(ITEM_FRAMES, &"coffee", Vector2(320.0, 212.0), 40.0)
	people.add_child(_cup)
	_new_zone()


func _new_zone() -> void:
	_zone_start = _rng.next() * (BAR_WIDTH - ZONE_WIDTHS[_round])
	_needle = 0.0
	_direction = 1.0


func _play(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			if _round >= ROUND_NAMES.size():
				end_early()
			else:
				_new_zone()
		_canvas.queue_redraw()
		return
	_needle += _direction * NEEDLE_SPEEDS[_round] * delta
	if _needle >= BAR_WIDTH or _needle <= 0.0:
		_needle = clampf(_needle, 0.0, BAR_WIDTH)
		_direction = -_direction
	_canvas.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if not is_playing() or _pause > 0.0 or _round >= ROUND_NAMES.size():
		return
	if event.is_action_pressed(InputActions.INTERACT):
		var inside: bool = _needle >= _zone_start and _needle <= _zone_start + ZONE_WIDTHS[_round]
		if inside:
			_hits += 1
			_big_label.text = "¡Perfecto!"
			AudioManager.play_sfx(&"pickup")
		else:
			_big_label.text = "¡Uy, se regó!"
			AudioManager.play_sfx(&"hit")
		_phase_time = 0.0
		_round += 1
		_pause = PAUSE_SECONDS


func _result() -> Dictionary:
	var summary: String = ["Se regó todo el tinto", "Tinto regular", "Buen tinto", "¡Tinto perfecto!"][_hits]
	return {"money": 0.0, "energy": ENERGY_BY_HITS[_hits], "time": 0.0, "summary": "%s (%d de 3)" % [summary, _hits]}


func _draw_scene() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("f0c987"))  # Morning wall.
	c.draw_rect(Rect2(0.0, 0.0, SCREEN.x, 70.0), Color("9cc9e8"))
	c.draw_rect(Rect2(170.0, 74.0, 300.0, 24.0), Color("c0392b"))  # Awning.
	for x: float in range(170, 470, 30):
		c.draw_rect(Rect2(x, 74.0, 15.0, 24.0), Color("f5f0e1"))
	c.draw_rect(Rect2(150.0, 212.0, 340.0, 34.0), Color("7a4a2b"))  # Counter.
	c.draw_rect(Rect2(150.0, 208.0, 340.0, 6.0), Color("a0673e"))
	c.draw_rect(Rect2(380.0, 176.0, 30.0, 34.0), Color("c9c9c9"))  # Thermos.
	c.draw_rect(Rect2(384.0, 170.0, 22.0, 8.0), Color("8a8a8a"))
	if not is_playing():
		return
	var left: float = (SCREEN.x - BAR_WIDTH) / 2.0
	var round_index: int = mini(_round, ROUND_NAMES.size() - 1)
	c.draw_string(c.get_theme_default_font(), Vector2(left, BAR_Y - 10.0), "%d/3  %s" % [round_index + 1, ROUND_NAMES[round_index]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	c.draw_rect(Rect2(left - 2.0, BAR_Y - 2.0, BAR_WIDTH + 4.0, 20.0), Color.BLACK)
	c.draw_rect(Rect2(left, BAR_Y, BAR_WIDTH, 16.0), Color("5b4636"))
	c.draw_rect(Rect2(left + _zone_start, BAR_Y, ZONE_WIDTHS[round_index], 16.0), Color("3fae5a"))
	c.draw_rect(Rect2(left + _needle - 2.0, BAR_Y - 6.0, 4.0, 28.0), Color.WHITE)
