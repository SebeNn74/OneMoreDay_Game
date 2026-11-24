class_name BusPickpocketMinigame
extends Minigame
## "Cuida la billetera": the bus is packed and hands reach for your pocket from the passengers on
## each side. Hands appear as a Poisson process (exponential gaps, λ = HAND_RATE). A slaps the
## left hand, D the right one. A hand that reaches the pocket takes $1.000; slapping the air
## locks that side for a moment, so spamming does not work.

const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_sprite_frames.tres")
const PASSENGER_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/enemy_sprite_frames.tres")

const HAND_RATE: float = 1.1
const REACH_SECONDS_START: float = 1.25  # Time a hand takes to reach the pocket...
const REACH_SECONDS_END: float = 0.8  # ...getting faster as the ride goes on.
const WHIFF_LOCK_SECONDS: float = 0.45
const MONEY_PER_THEFT: float = -1.0
const MAX_THEFTS_CHARGED: int = 4

const FLOOR_Y: float = 296.0
const PLAYER_X: float = 320.0
const POCKET: Vector2 = Vector2(320.0, 258.0)
const PASSENGER_X: Dictionary = {-1: 210.0, 1: 430.0}
const WINDOW_TOP: float = 64.0
const WINDOW_BOTTOM: float = 172.0
const CRUISE_SPEED: float = 140.0
const SKIN: Color = Color("c68a5b")
const SLEEVES: Dictionary = {-1: Color("6b3f2a"), 1: Color("37506e")}
const ALERT_COLOR: Color = Color(1.0, 0.85, 0.3)

## side (-1 left, +1 right) -> {progress: 0..1, retracting: bool}
var _hands: Dictionary = {}
var _locked: Dictionary = {-1: 0.0, 1: 0.0}
var _next_hand: float = 0.8
var _spawned: int = 0
var _slapped: int = 0
var _thefts: int = 0
var _whiffs: int = 0
var _city_offset: float = 0.0
var _canvas: Control
var _front: Control
var _player: AnimatedSprite2D
var _thieves: Dictionary = {}  # side -> AnimatedSprite2D
var _buildings: Array[Rect2] = []
var _building_colors: Array[Color] = []
var _rng: Lcg


func _init() -> void:
	title = "Cuida la billetera"
	instructions = "El bus va lleno y hay manos largas. Cuando una mano salga hacia tu bolsillo, dale un manotazo: A para la de la izquierda, D para la de la derecha. Cada mano que llegue te roba $1.000. Si das manotazos al aire, pierdes un momento."
	duration_seconds = 12.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_make_city()
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_bus)
	stage.add_child(_canvas)
	var people: Node2D = Node2D.new()
	stage.add_child(people)
	_thieves[-1] = _sprite(PASSENGER_FRAMES, &"crowd_b_right", Vector2(PASSENGER_X[-1], FLOOR_Y), 80.0)
	_thieves[1] = _sprite(PASSENGER_FRAMES, &"crowd_a_left", Vector2(PASSENGER_X[1], FLOOR_Y), 80.0)
	people.add_child(_thieves[-1])
	people.add_child(_thieves[1])
	people.add_child(_sprite(PASSENGER_FRAMES, &"crowd_c_right", Vector2(110.0, FLOOR_Y), 72.0))
	people.add_child(_sprite(PASSENGER_FRAMES, &"suspicious_brown_left", Vector2(540.0, FLOOR_Y), 72.0))
	_player = _sprite(PLAYER_FRAMES, &"idle_down", Vector2(PLAYER_X, FLOOR_Y), 80.0)
	people.add_child(_player)
	_front = Control.new()  # Hands and hints over the people.
	_front.size = SCREEN
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	stage.add_child(_front)


func _make_city() -> void:
	var palette: Array[Color] = [Color("c9824a"), Color("d8b46a"), Color("8fa7b8"), Color("b65f4f"), Color("e0d2b4"), Color("7f8c6a")]
	var x: float = 0.0
	while x < SCREEN.x * 2.0:
		var width: float = 40.0 + _rng.next() * 50.0
		var height: float = 40.0 + _rng.next() * 70.0
		_buildings.append(Rect2(x, WINDOW_BOTTOM - height, width - 4.0, height))
		_building_colors.append(palette[_rng.index(palette.size())])
		x += width


func _reach_seconds() -> float:
	return lerpf(REACH_SECONDS_START, REACH_SECONDS_END, 1.0 - _time_left / duration_seconds)


func _play(delta: float) -> void:
	_city_offset = fmod(_city_offset + CRUISE_SPEED * delta, SCREEN.x * 2.0)
	for side: int in _locked:
		_locked[side] = maxf(_locked[side] - delta, 0.0)

	_next_hand -= delta
	if _next_hand <= 0.0:
		_next_hand = _rng.exponential(HAND_RATE)
		var free: Array[int] = []
		for side: int in [-1, 1]:
			if not _hands.has(side):
				free.append(side)
		if not free.is_empty() and _time_left > 0.8:
			_hands[free[_rng.index(free.size())]] = {"progress": 0.0, "retracting": false}
			_spawned += 1

	for side: int in _hands.keys():
		var hand: Dictionary = _hands[side]
		if hand.retracting:
			hand.progress -= delta * 3.0
			if hand.progress <= 0.0:
				_hands.erase(side)
			continue
		hand.progress += delta / _reach_seconds()
		if hand.progress >= 1.0:
			_thefts += 1
			_big_label.text = "¡Te sacaron $1.000!"
			_phase_time = 0.0
			AudioManager.play_sfx(&"fall")
			hand.retracting = true
	for side: int in _thieves:  # The thief reaching for you turns red.
		var reaching: bool = _hands.has(side) and not _hands[side].retracting
		_thieves[side].modulate = Color(1.0, 0.55, 0.5) if reaching else Color.WHITE
	_canvas.queue_redraw()
	_front.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if not is_playing():
		return
	var side: int = 0
	if event.is_action_pressed(InputActions.MOVE_LEFT):
		side = -1
	elif event.is_action_pressed(InputActions.MOVE_RIGHT):
		side = 1
	if side == 0 or _locked[side] > 0.0:
		return
	var hand: Variant = _hands.get(side)
	if hand != null and not hand.retracting:
		hand.retracting = true
		_slapped += 1
		_big_label.text = "¡Pillado!"
		_phase_time = 0.0
		AudioManager.play_sfx(&"hit", 1.2)
	else:
		_whiffs += 1
		_locked[side] = WHIFF_LOCK_SECONDS
		AudioManager.play_sfx(&"ui_move", 0.7)


func _result() -> Dictionary:
	Simulation.report(Simulation.MODEL_MONTE_CARLO, "Bus: %d manos (llegadas de Poisson, λ = %.1f/s), %d pilladas, %d robos" % [
		_spawned, HAND_RATE, _slapped, _thefts])
	var charged: int = mini(_thefts, MAX_THEFTS_CHARGED)
	var summary: String = "¡Nadie te robó! Pillaste %d manos" % _slapped if _thefts == 0 else (
		"Pillaste %d manos, pero te robaron %d %s" % [_slapped, _thefts, "vez" if _thefts == 1 else "veces"])
	return {"money": MONEY_PER_THEFT * charged, "energy": 0.0, "time": 0.0, "summary": summary}


func _draw_bus() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("d9d2bf"))  # Wall.
	c.draw_rect(Rect2(0.0, WINDOW_TOP, SCREEN.x, WINDOW_BOTTOM - WINDOW_TOP), Color("9cc9e8"))  # Sky.
	for i: int in _buildings.size():
		var rect: Rect2 = _buildings[i]
		var x: float = fposmod(rect.position.x - _city_offset, SCREEN.x * 2.0) - 60.0
		c.draw_rect(Rect2(x, rect.position.y, rect.size.x, rect.size.y), _building_colors[i])
		for wy: float in range(int(rect.position.y) + 8, int(WINDOW_BOTTOM) - 8, 14):
			c.draw_rect(Rect2(x + 6.0, wy, rect.size.x - 12.0, 5.0), Color(1.0, 1.0, 0.85, 0.5))
	for wx: float in range(0, int(SCREEN.x) + 1, 160):  # Window frames.
		c.draw_rect(Rect2(wx - 5.0, WINDOW_TOP, 10.0, WINDOW_BOTTOM - WINDOW_TOP), Color("5a5f66"))
	c.draw_rect(Rect2(0.0, WINDOW_TOP - 6.0, SCREEN.x, 6.0), Color("5a5f66"))
	c.draw_rect(Rect2(0.0, WINDOW_BOTTOM, SCREEN.x, 6.0), Color("5a5f66"))
	c.draw_rect(Rect2(0.0, 34.0, SCREEN.x, 5.0), Color("b9bcc0"))  # Handrail.
	c.draw_rect(Rect2(0.0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), Color("6d6f73"))  # Floor.
	c.draw_rect(Rect2(0.0, FLOOR_Y, SCREEN.x, 3.0), Color("e8c547"))


func _draw_front() -> void:
	var f: Control = _front
	# The wallet sticking out of the back pocket.
	f.draw_rect(Rect2(POCKET + Vector2(-7.0, -5.0), Vector2(14.0, 10.0)), Color("5b3a1e"))
	f.draw_rect(Rect2(POCKET + Vector2(-5.0, -3.0), Vector2(10.0, 3.0)), Color("3fae5a"))
	for side: int in _hands:
		var hand: Dictionary = _hands[side]
		var shoulder: Vector2 = Vector2(PASSENGER_X[side] - side * 6.0, POCKET.y - 6.0)
		var tip: Vector2 = shoulder.lerp(POCKET + Vector2(side * 10.0, 0.0), clampf(hand.progress, 0.0, 1.0))
		f.draw_line(shoulder, tip, Color.BLACK, 13.0)
		f.draw_line(shoulder, tip, SLEEVES[side], 10.0)
		f.draw_circle(tip, 10.0, Color.BLACK)
		f.draw_circle(tip, 8.5, SKIN)
		if not hand.retracting:  # Alert over the thief, bobbing.
			var bob: float = sin(Time.get_ticks_msec() / 70.0) * 3.0
			f.draw_string(f.get_theme_default_font(), Vector2(PASSENGER_X[side] - 8.0, FLOOR_Y - 96.0 + bob), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.3, 0.25))
	if not is_playing():
		return
	var font: Font = f.get_theme_default_font()
	for side: int in [-1, 1]:  # The key under each thief.
		var label: String = "A" if side < 0 else "D"
		var color: Color = Color(1.0, 1.0, 1.0, 0.3) if _locked[side] > 0.0 else ALERT_COLOR
		f.draw_rect(Rect2(PASSENGER_X[side] - 14.0, 308.0, 28.0, 26.0), Color(0.0, 0.0, 0.0, 0.6))
		f.draw_string(font, Vector2(PASSENGER_X[side] - 6.0, 328.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
	f.draw_string(font, Vector2(20.0, 350.0), "Robos: %d" % _thefts, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
