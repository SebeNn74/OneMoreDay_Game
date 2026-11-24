class_name TaxiTrafficMinigame
extends Minigame
## "Esquiva el trancón": the taxi drives up a three-lane avenue. Slower cars and motos appear ahead
## as a Poisson process (exponential gaps, λ = SPAWN_RATE). A/D change lanes. Each crash costs
## time and the meter keeps running (money).

const VEHICLE_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/enemy_sprite_frames.tres")
const LANE_X: Array[float] = [200.0, 320.0, 440.0]
const ROAD_LEFT: float = 140.0
const ROAD_RIGHT: float = 500.0
const TAXI_Y: float = 296.0
const ROAD_SPEED: float = 280.0  # How fast the street scrolls under the taxi.
const LANE_CHANGE_SPEED: float = 900.0
## Traffic: Poisson arrivals; each vehicle drives slower than the taxi, so it comes down the screen.
const SPAWN_RATE: float = 1.5
const MIN_RELATIVE_SPEED: float = 150.0
const MAX_RELATIVE_SPEED: float = 230.0
## Never close every lane: at most this many lanes hold a vehicle near the top at once.
const MAX_BLOCKED_LANES: int = 2
const SPAWN_BAND: float = 170.0
const INVULNERABLE_SECONDS: float = 0.9
const TIME_PER_CRASH: float = -3.0
const MONEY_PER_CRASH: float = -1.0
const MAX_CRASHES_CHARGED: int = 4
const TYPES: Array[StringName] = [&"car_red_up", &"moto_blue_up", &"moto_red_up"]

var _lane: int = 1
var _taxi: AnimatedSprite2D
var _vehicles: Array[Dictionary] = []  # {sprite, lane, speed, half}
var _next_spawn: float = 0.6
var _spawned: int = 0
var _crashes: int = 0
var _invulnerable: float = 0.0
var _scroll: float = 0.0
var _canvas: Control
var _traffic: Node2D
var _rng: Lcg


func _init() -> void:
	title = "Esquiva el trancón"
	instructions = "El taxi va por la avenida. Cambia de carril con A y D para no chocar con los carros y motos. Cada choque te quita tiempo y el taxímetro sigue corriendo."
	duration_seconds = 12.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_street)
	stage.add_child(_canvas)
	_traffic = Node2D.new()
	stage.add_child(_traffic)
	_taxi = _vehicle_sprite(&"car_taxi_up")
	_taxi.position = Vector2(LANE_X[_lane], TAXI_Y)
	_traffic.add_child(_taxi)


func _vehicle_sprite(animation: StringName) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = VEHICLE_FRAMES
	sprite.animation = animation
	var width: float = VEHICLE_FRAMES.get_frame_texture(animation, 0).get_width()
	var lane_fill: float = 0.75 if animation.begins_with(&"car") else 0.5
	sprite.scale = Vector2.ONE * ((ROAD_RIGHT - ROAD_LEFT) / 3.0 * lane_fill / width)
	sprite.play()
	return sprite


func _on_input(event: InputEvent) -> void:
	if not is_playing():
		return
	if event.is_action_pressed(InputActions.MOVE_LEFT):
		_lane = maxi(_lane - 1, 0)
	elif event.is_action_pressed(InputActions.MOVE_RIGHT):
		_lane = mini(_lane + 1, LANE_X.size() - 1)


func _play(delta: float) -> void:
	_scroll = fmod(_scroll + ROAD_SPEED * delta, 64.0)
	_taxi.position.x = move_toward(_taxi.position.x, LANE_X[_lane], LANE_CHANGE_SPEED * delta)
	if _invulnerable > 0.0:
		_invulnerable -= delta
		_taxi.visible = int(_invulnerable * 12.0) % 2 == 0 or _invulnerable <= 0.0

	_next_spawn -= delta
	if _next_spawn <= 0.0 and _time_left > 1.5:
		_spawn()
		_next_spawn = _rng.exponential(SPAWN_RATE)

	var taxi_half: Vector2 = _half_size(_taxi)
	for i: int in range(_vehicles.size() - 1, -1, -1):
		var vehicle: Dictionary = _vehicles[i]
		var sprite: AnimatedSprite2D = vehicle.sprite
		sprite.position.y += vehicle.speed * delta
		var gap: Vector2 = (sprite.position - _taxi.position).abs()
		var reach: Vector2 = (taxi_half + vehicle.half) * Vector2(0.7, 0.75)
		if _invulnerable <= 0.0 and gap.x < reach.x and gap.y < reach.y:
			_crash()
			sprite.queue_free()
			_vehicles.remove_at(i)
		elif sprite.position.y - vehicle.half.y > SCREEN.y:
			sprite.queue_free()
			_vehicles.remove_at(i)
	_canvas.queue_redraw()


func _spawn() -> void:
	var busy: Array[int] = []
	for vehicle: Dictionary in _vehicles:
		if (vehicle.sprite as AnimatedSprite2D).position.y < SPAWN_BAND and vehicle.lane not in busy:
			busy.append(vehicle.lane)
	if busy.size() >= MAX_BLOCKED_LANES:
		return
	var free: Array[int] = []
	for lane: int in LANE_X.size():
		if lane not in busy:
			free.append(lane)
	var lane: int = free[_rng.index(free.size())]
	var sprite: AnimatedSprite2D = _vehicle_sprite(TYPES[_rng.index(TYPES.size())])
	var half: Vector2 = _half_size(sprite)
	sprite.position = Vector2(LANE_X[lane], -half.y)
	_traffic.add_child(sprite)
	_vehicles.append({
		"sprite": sprite, "lane": lane, "half": half,
		"speed": MIN_RELATIVE_SPEED + _rng.next() * (MAX_RELATIVE_SPEED - MIN_RELATIVE_SPEED),
	})
	_spawned += 1


func _half_size(sprite: AnimatedSprite2D) -> Vector2:
	return sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size() * sprite.scale / 2.0


func _crash() -> void:
	_crashes += 1
	_invulnerable = INVULNERABLE_SECONDS
	AudioManager.play_sfx(&"crash")
	AudioManager.play_sfx(&"honk", 1.1)
	_big_label.text = "¡Choque!"
	_phase_time = 0.0


func _result() -> Dictionary:
	Simulation.report(Simulation.MODEL_MONTE_CARLO, "Taxi: %d vehículos (llegadas de Poisson, λ = %.1f/s), %d choques" % [
		_spawned, SPAWN_RATE, _crashes])
	var charged: int = mini(_crashes, MAX_CRASHES_CHARGED)
	var summary: String = "¡Viaje limpio, sin choques!" if _crashes == 0 else (
		"Chocaste 1 vez" if _crashes == 1 else "Chocaste %d veces" % _crashes)
	return {"money": MONEY_PER_CRASH * charged, "energy": 0.0, "time": TIME_PER_CRASH * charged, "summary": summary}


func _draw_street() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("b8b0a0"))  # Sidewalks.
	for side: float in [0.0, ROAD_RIGHT + 24.0]:  # Buildings sliding by.
		var y: float = fposmod(_scroll * 2.0, 128.0) - 128.0
		while y < SCREEN.y:
			c.draw_rect(Rect2(side + 8.0, y + 6.0, 108.0, 116.0), Color("9a6b4f") if int(y) % 256 < 128 else Color("7d8a9a"))
			y += 128.0
	c.draw_rect(Rect2(ROAD_LEFT - 8.0, 0.0, 8.0, SCREEN.y), Color("8a8478"))  # Curbs.
	c.draw_rect(Rect2(ROAD_RIGHT, 0.0, 8.0, SCREEN.y), Color("8a8478"))
	c.draw_rect(Rect2(ROAD_LEFT, 0.0, ROAD_RIGHT - ROAD_LEFT, SCREEN.y), Color("4a4c50"))  # Road.
	var lane_width: float = (ROAD_RIGHT - ROAD_LEFT) / 3.0
	for k: int in [1, 2]:
		var x: float = ROAD_LEFT + lane_width * k
		var y: float = _scroll - 64.0
		while y < SCREEN.y:
			c.draw_rect(Rect2(x - 2.0, y, 4.0, 30.0), Color("e8e4d8"))
			y += 64.0
