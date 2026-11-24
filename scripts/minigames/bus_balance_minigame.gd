class_name BusBalanceMinigame
extends Minigame
## "Aguanta el viaje": standing in the bus, keep your balance while it brakes and speeds up.
## The lean is an unstable pendulum (it grows on its own) pushed by braking jolts that arrive as a
## Poisson process (exponential gaps, λ = JOLT_RATE). A/D push back. Leaning to the edge is a fall.

const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_sprite_frames.tres")
const PASSENGER_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/enemy_sprite_frames.tres")

## Lean dynamics: dv/dt = INSTABILITY·lean + CONTROL·input − DAMPING·v ; dlean/dt = v (A = −1, D = +1).
const INSTABILITY: float = 1.6
const CONTROL: float = 3.4
const DAMPING: float = 1.6
## Braking jolts: Poisson arrivals with this rate (per second) and a random push.
const JOLT_RATE: float = 0.9
const JOLT_MIN: float = 1.3
const JOLT_MAX: float = 2.5
const SAFE_LEAN: float = 0.35
const WARN_LEAN: float = 0.7
const FALL_SECONDS: float = 0.9
const MAX_LEAN_RADIANS: float = 0.55
const ENERGY_PER_FALL: float = -4.0
const MAX_FALLS_CHARGED: int = 3

const FLOOR_Y: float = 296.0
const POLE_X: float = 320.0
const WINDOW_TOP: float = 64.0
const WINDOW_BOTTOM: float = 172.0
const CRUISE_SPEED: float = 140.0  # px/s of the city behind the windows.
const METER_WIDTH: float = 300.0
const METER_Y: float = 326.0

var _lean: float = 0.0
var _lean_speed: float = 0.0
var _next_jolt: float = 0.0
var _jolts: int = 0
var _falls: int = 0
var _fall_left: float = 0.0
var _city_offset: float = 0.0
var _city_speed: float = CRUISE_SPEED
var _canvas: Control
var _player: AnimatedSprite2D
var _passengers: Array[AnimatedSprite2D] = []
var _buildings: Array[Rect2] = []
var _building_colors: Array[Color] = []
var _rng: Lcg


func _init() -> void:
	title = "Aguanta el viaje"
	instructions = "Vas de pie en el bus. Con cada frenazo te vas para un lado: usa A y D para no perder el equilibrio. Si la aguja llega al rojo te caes y pierdes energía."
	duration_seconds = 12.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_next_jolt = 1.0 + _rng.exponential(JOLT_RATE)
	_make_city()
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_bus)
	stage.add_child(_canvas)
	var people: Node2D = Node2D.new()
	stage.add_child(people)
	for spec: Array in [[&"crowd_b_right", 150.0], [&"crowd_a_left", 470.0], [&"crowd_c_right", 548.0]]:
		var passenger: AnimatedSprite2D = _person(PASSENGER_FRAMES, spec[0], spec[1])
		people.add_child(passenger)
		_passengers.append(passenger)
	_player = _person(PLAYER_FRAMES, &"idle_right", POLE_X - 26.0)
	people.add_child(_player)
	var front: Control = Control.new()  # Meter drawn over the people.
	front.size = SCREEN
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_meter.bind(front))
	stage.add_child(front)
	_canvas.set_meta("front", front)


func _person(frames: SpriteFrames, animation: StringName, x: float) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = animation
	var height: float = frames.get_frame_texture(animation, 0).get_height()
	sprite.offset = Vector2(0.0, -height / 2.0)  # Origin at the feet, so it leans from them.
	sprite.scale = Vector2.ONE * (72.0 / height)
	sprite.position = Vector2(x, FLOOR_Y)
	sprite.play()
	return sprite


func _make_city() -> void:
	var palette: Array[Color] = [Color("c9824a"), Color("d8b46a"), Color("8fa7b8"), Color("b65f4f"), Color("e0d2b4"), Color("7f8c6a")]
	var x: float = 0.0
	while x < SCREEN.x * 2.0:
		var width: float = 40.0 + _rng.next() * 50.0
		var height: float = 40.0 + _rng.next() * 70.0
		_buildings.append(Rect2(x, WINDOW_BOTTOM - height, width - 4.0, height))
		_building_colors.append(palette[_rng.index(palette.size())])
		x += width


func _play(delta: float) -> void:
	_next_jolt -= delta
	if _next_jolt <= 0.0:
		_jolts += 1
		var push: float = (JOLT_MIN + _rng.next() * (JOLT_MAX - JOLT_MIN)) * (1.0 if _rng.next() < 0.5 else -1.0)
		_lean_speed += push
		_city_speed = CRUISE_SPEED * (0.3 if push > 0.0 else 1.6)  # Leaning forward = braking.
		_next_jolt = _rng.exponential(JOLT_RATE)
		AudioManager.play_sfx(&"jolt", 0.8 + absf(push) * 0.15)
		if absf(push) > 1.7:
			_big_label.text = "¡Frenazo!" if push > 0.0 else "¡Arrancón!"
			_phase_time = 0.0
	_city_speed = move_toward(_city_speed, CRUISE_SPEED, 120.0 * delta)
	_city_offset = fmod(_city_offset + _city_speed * delta, SCREEN.x * 2.0)

	if _fall_left > 0.0:
		_fall_left -= delta
		if _fall_left <= 0.0:
			_player.play(&"idle_right")
	else:
		var input: float = Input.get_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT)
		_lean_speed += (INSTABILITY * _lean + CONTROL * input - DAMPING * _lean_speed) * delta
		_lean = clampf(_lean + _lean_speed * delta, -1.0, 1.0)
		if absf(_lean) >= 1.0:
			_fall()
	_player.rotation = _lean * MAX_LEAN_RADIANS
	for i: int in _passengers.size():
		_passengers[i].rotation = lerp_angle(_passengers[i].rotation, _lean * MAX_LEAN_RADIANS * 0.6, delta * (2.0 + i))
	_canvas.queue_redraw()
	(_canvas.get_meta("front") as Control).queue_redraw()


func _fall() -> void:
	_falls += 1
	_fall_left = FALL_SECONDS
	_lean = 0.0
	_lean_speed = 0.0
	_player.play(&"fall")
	AudioManager.play_sfx(&"fall")
	_big_label.text = "¡Te caíste!"
	_phase_time = 0.0


func _result() -> Dictionary:
	Simulation.report(Simulation.MODEL_MONTE_CARLO, "Bus: %d frenazos (llegadas de Poisson, λ = %.1f/s), %d caídas" % [
		_jolts, JOLT_RATE, _falls])
	var charged: int = mini(_falls, MAX_FALLS_CHARGED)
	var summary: String = "¡Ni un tropezón!" if _falls == 0 else (
		"Te caíste 1 vez" if _falls == 1 else "Te caíste %d veces" % _falls)
	return {"money": 0.0, "energy": ENERGY_PER_FALL * charged, "time": 0.0, "summary": summary}


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
	for sx: float in [40.0, 250.0, 390.0, 600.0]:  # Seats.
		c.draw_rect(Rect2(sx - 30.0, 236.0, 60.0, 34.0), Color("3f6fb5"))
		c.draw_rect(Rect2(sx - 30.0, 206.0, 10.0, 64.0), Color("335d99"))
	c.draw_rect(Rect2(0.0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), Color("6d6f73"))  # Floor.
	c.draw_rect(Rect2(0.0, FLOOR_Y, SCREEN.x, 3.0), Color("e8c547"))
	c.draw_rect(Rect2(POLE_X - 4.0, 36.0, 8.0, FLOOR_Y - 36.0), Color("e8c547"))  # Pole.


func _draw_meter(front: Control) -> void:
	if not is_playing():
		return
	var left: float = (SCREEN.x - METER_WIDTH) / 2.0
	var half: float = METER_WIDTH / 2.0
	var center: float = left + half
	front.draw_rect(Rect2(left - 2.0, METER_Y - 2.0, METER_WIDTH + 4.0, 16.0), Color.BLACK)
	front.draw_rect(Rect2(left, METER_Y, METER_WIDTH, 12.0), Color("c0392b"))
	front.draw_rect(Rect2(center - half * WARN_LEAN, METER_Y, METER_WIDTH * WARN_LEAN, 12.0), Color("e1a33a"))
	front.draw_rect(Rect2(center - half * SAFE_LEAN, METER_Y, METER_WIDTH * SAFE_LEAN, 12.0), Color("3fae5a"))
	var needle: float = center + _lean * half
	front.draw_rect(Rect2(needle - 2.0, METER_Y - 5.0, 4.0, 22.0), Color.WHITE)
	front.draw_string(ThemeDB.fallback_font, Vector2(left, METER_Y - 6.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	front.draw_string(ThemeDB.fallback_font, Vector2(left + METER_WIDTH - 8.0, METER_Y - 6.0), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
