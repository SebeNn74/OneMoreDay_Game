class_name TintoTimingMinigame
extends Minigame
## "Sirve el tinto": fill three cups up to the line. Hold E to open the thermos tap.
## Model: system dynamics. The coffee in the cup is a stock fed by a flow:
##   dQ/dt = k·(1 − Q)   while E is held (the tap opens: the flow q rises toward its maximum)
##   dQ/dt = −c·Q        when released (the tap closes, but slowly)
##   dL/dt = q           (the level is the accumulated flow)
## So the coffee keeps pouring for a moment after releasing: the player must stop early.
## Integrated with Euler, one step per frame. Each cup scores by how close it ends to the line.

const NPC_FRAMES: SpriteFrames = preload("res://assets/sprites/npcs/npc_sprite_frames.tres")
const CUPS: int = 3
const TARGETS: Array[float] = [0.7, 0.55, 0.8]
const MAX_FLOW: float = 0.6  # Fraction of the cup per second with the tap fully open.
const OPEN_RATE: float = 4.0  # k
const CLOSE_RATE: float = 4.0  # c (after releasing, about MAX_FLOW / c more coffee falls)
const GOOD_ERROR: float = 0.06
const OK_ERROR: float = 0.14
const SETTLE_SECONDS: float = 0.9
## Energy on top of the option's own effect, by good cups (0..3).
const ENERGY_BY_GOOD: Array[float] = [-3.0, 0.0, 3.0, 6.0]

const CUP_RECT: Rect2 = Rect2(280.0, 200.0, 80.0, 100.0)

var _cup: int = 0
var _level: float = 0.0
var _flow: float = 0.0
var _opening: float = 0.0  # 0..1, how open the tap is (Q).
var _touched: bool = false
var _settle: float = 0.0
var _good: int = 0
var _errors: Array[float] = []
var _canvas: Control


func _init() -> void:
	title = "Sirve el tinto"
	instructions = "La vendedora te deja servir tu tinto. Mantén E para abrir el termo y suéltalo para cerrarlo; el chorro tarda en cortarse, así que suelta un poco antes de la raya. Tres pocillos: bien servido te da más energía."
	model_name = "Dinámica de sistemas"
	duration_seconds = 18.0


func _build(stage: Control) -> void:
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	stage.add_child(_canvas)
	var people: Node2D = Node2D.new()
	stage.add_child(people)
	people.add_child(_sprite(NPC_FRAMES, &"coffee_vendor", Vector2(470.0, 196.0), 96.0))


func _play(delta: float) -> void:
	if _cup >= CUPS:
		return
	var holding: bool = Input.is_action_pressed(InputActions.INTERACT)
	if holding:
		_touched = true
		_settle = 0.0
	# Stocks and flows, Euler step.
	if holding:
		_opening += OPEN_RATE * (1.0 - _opening) * delta
	else:
		_opening -= CLOSE_RATE * _opening * delta
	_flow = MAX_FLOW * _opening
	_level = minf(_level + _flow * delta, 1.1)
	# A cup is done once the player poured and the stream has (almost) stopped.
	if _touched and not holding and _flow < 0.02:
		_settle += delta
		if _settle >= SETTLE_SECONDS:
			_finish_cup()
	_canvas.queue_redraw()


func _finish_cup() -> void:
	var error: float = absf(_level - TARGETS[_cup])
	_errors.append(error)
	if error <= GOOD_ERROR:
		_good += 1
		_big_label.text = "¡Perfecto!"
		AudioManager.play_sfx(&"pickup")
	elif error <= OK_ERROR:
		_big_label.text = "Casi"
		AudioManager.play_sfx(&"ui_confirm")
	else:
		_big_label.text = "¡Se regó!" if _level > TARGETS[_cup] else "Quedó corto"
		AudioManager.play_sfx(&"hit")
	_phase_time = 0.0
	_cup += 1
	_level = 0.0
	_opening = 0.0
	_flow = 0.0
	_touched = false
	_settle = 0.0
	if _cup >= CUPS:
		end_early()


func _model_text() -> String:
	return "nivel L = %.2f (raya %.2f)   caudal q = %.2f/s\ndL/dt = q   ·   dq/dt sube al abrir, baja con c = %.1f" % [
		_level, TARGETS[mini(_cup, CUPS - 1)], _flow, CLOSE_RATE]


func _result() -> Dictionary:
	var mean_error: float = 0.0
	for e: float in _errors:
		mean_error += e
	mean_error /= maxf(_errors.size(), 1.0)
	Simulation.report(Simulation.MODEL_DYNAMICS, "Tinto: %d pocillos, error medio de nivel %.2f (Euler, dt = 1 frame)" % [
		_errors.size(), mean_error])
	var summary: String = ["Se regó todo el tinto", "Tinto regular", "Buen tinto", "¡Tinto perfecto!"][_good]
	if _errors.size() < CUPS:
		summary = "No alcanzaste a servir los 3 pocillos"
	return {"money": 0.0, "energy": ENERGY_BY_GOOD[_good], "time": 0.0, "summary": "%s (%d de 3 bien servidos)" % [summary, _good]}


func _draw_scene() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("f0c987"))  # Morning wall.
	c.draw_rect(Rect2(0.0, 0.0, SCREEN.x, 70.0), Color("9cc9e8"))
	c.draw_rect(Rect2(170.0, 74.0, 300.0, 24.0), Color("c0392b"))  # Awning.
	for x: float in range(170, 470, 30):
		c.draw_rect(Rect2(x, 74.0, 15.0, 24.0), Color("f5f0e1"))
	c.draw_rect(Rect2(150.0, 300.0, 340.0, 34.0), Color("7a4a2b"))  # Counter.
	c.draw_rect(Rect2(150.0, 296.0, 340.0, 6.0), Color("a0673e"))
	# Thermos with its tap over the cup.
	c.draw_rect(Rect2(292.0, 110.0, 56.0, 60.0), Color("c9c9c9"))
	c.draw_rect(Rect2(296.0, 104.0, 48.0, 8.0), Color("8a8a8a"))
	c.draw_rect(Rect2(314.0, 170.0, 12.0, 10.0), Color("555555"))
	var stream: float = clampf(_flow / MAX_FLOW, 0.0, 1.0)
	if stream > 0.02:
		c.draw_rect(Rect2(320.0 - 3.0 * stream, 180.0, 6.0 * stream, CUP_RECT.position.y + CUP_RECT.size.y * (1.0 - _level) - 180.0), Color("3b2414"))
	# The cup: coffee level, and the line to reach.
	c.draw_rect(CUP_RECT.grow(4.0), Color.BLACK)
	c.draw_rect(CUP_RECT, Color("f5f0e1"))
	var filled: float = clampf(_level, 0.0, 1.0) * CUP_RECT.size.y
	c.draw_rect(Rect2(CUP_RECT.position.x, CUP_RECT.end.y - filled, CUP_RECT.size.x, filled), Color("4a2c17"))
	if _level > 1.0:  # Spilling over.
		c.draw_rect(Rect2(CUP_RECT.position.x - 10.0, CUP_RECT.end.y - 6.0, CUP_RECT.size.x + 20.0, 8.0), Color("4a2c17"))
	if _cup < CUPS:
		var line_y: float = CUP_RECT.end.y - TARGETS[_cup] * CUP_RECT.size.y
		c.draw_line(Vector2(CUP_RECT.position.x - 12.0, line_y), Vector2(CUP_RECT.end.x + 12.0, line_y), Color("3fae5a"), 3.0)
	if not is_playing():
		return
	var font: Font = c.get_theme_default_font()
	c.draw_string(font, Vector2(20.0, 340.0), "Pocillo %d de %d   ·   bien servidos: %d" % [mini(_cup + 1, CUPS), CUPS, _good], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	c.draw_string(font, Vector2(CUP_RECT.end.x + 20.0, CUP_RECT.position.y + 40.0), "Mantén E", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
