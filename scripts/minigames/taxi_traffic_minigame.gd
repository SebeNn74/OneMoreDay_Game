class_name TaxiTrafficMinigame
extends Minigame
## "Esquiva el trancón": the taxi drives up a three-lane avenue. Slower cars and motos appear ahead
## (exponential gaps, λ = SPAWN_RATE). A/D change lanes. Each crash costs time and the meter keeps
## running (money).
## Model: random walk. Every WALK_TICK each vehicle takes one step of a random walk over the lanes:
## left with P_LEFT, right with P_RIGHT, stays otherwise (a step into the curb is not taken). It turns
## on the blinker BLINK_SECONDS before moving, so the player can react to the weaving traffic.

const VEHICLE_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/enemy_sprite_frames.tres")
const LANE_X: Array[float] = [200.0, 320.0, 440.0]
const ROAD_LEFT: float = 140.0
const ROAD_RIGHT: float = 500.0
const TAXI_Y: float = 296.0
const ROAD_SPEED: float = 280.0  # How fast the street scrolls under the taxi.
const LANE_CHANGE_SPEED: float = 900.0
## Traffic: Poisson arrivals; each vehicle drives slower than the taxi, so it comes down the screen.
const SPAWN_RATE: float = 1.3
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
## Random walk over the lanes.
const WALK_TICK: float = 0.8
const P_LEFT: float = 0.2
const P_RIGHT: float = 0.2
const BLINK_SECONDS: float = 0.4
const VEHICLE_LANE_SPEED: float = 260.0

var _lane: int = 1
var _taxi: AnimatedSprite2D
var _vehicles: Array[Dictionary] = []  # {sprite, lane, speed, half, tick, next_lane, blink}
var _next_spawn: float = 0.6
var _spawned: int = 0
var _crashes: int = 0
var _invulnerable: float = 0.0
var _scroll: float = 0.0
var _canvas: Control
var _traffic: Node2D
var _rng: Lcg
var _steps: Array[int] = [0, 0, 0]  # Random walk steps taken: left, stay, right.


func _init() -> void:
	title = "Esquiva el trancón"
	instructions = "El taxi va por la avenida. Cambia de carril con {left} y {right} para no chocar. Los carros y motos zigzaguean al azar (caminata aleatoria): miren su direccional amarilla antes de que se pasen de carril. Cada choque te quita tiempo y el taxímetro sigue corriendo."
	model_name = "Caminata aleatoria"
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
		_walk(vehicle, delta)
		sprite.position.x = move_toward(sprite.position.x, LANE_X[vehicle.lane], VEHICLE_LANE_SPEED * delta)
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
		"tick": WALK_TICK * _rng.next(), "next_lane": lane, "blink": 0.0,
	})
	_spawned += 1


## One step of the random walk: decide (and blink), then change lane after BLINK_SECONDS.
func _walk(vehicle: Dictionary, delta: float) -> void:
	if vehicle.blink > 0.0:
		vehicle.blink -= delta
		if vehicle.blink <= 0.0:
			vehicle.lane = vehicle.next_lane
		return
	vehicle.tick -= delta
	if vehicle.tick > 0.0:
		return
	vehicle.tick += WALK_TICK
	var u: float = _rng.next()
	var step: int = -1 if u < P_LEFT else (1 if u < P_LEFT + P_RIGHT else 0)
	_steps[step + 1] += 1
	var target: int = vehicle.lane + step
	if step != 0 and target >= 0 and target < LANE_X.size():
		vehicle.next_lane = target
		vehicle.blink = BLINK_SECONDS


func _model_text() -> String:
	var total: int = maxi(_steps[0] + _steps[1] + _steps[2], 1)
	return "Cada %.1f s: P(izq) = %.2f  P(der) = %.2f  P(seguir) = %.2f\nPasos observados: izq %.2f  seguir %.2f  der %.2f" % [
		WALK_TICK, P_LEFT, P_RIGHT, 1.0 - P_LEFT - P_RIGHT,
		float(_steps[0]) / total, float(_steps[1]) / total, float(_steps[2]) / total]


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
	var total: int = maxi(_steps[0] + _steps[1] + _steps[2], 1)
	Simulation.report(Simulation.MODEL_RANDOM_WALK, "Taxi: %d pasos de caminata en %d vehículos (izq %.2f / der %.2f, teórico %.2f), %d choques" % [
		total, _spawned, float(_steps[0]) / total, float(_steps[2]) / total, P_LEFT, _crashes])
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
	for vehicle: Dictionary in _vehicles:  # Blinkers of the vehicles about to change lane.
		if vehicle.blink > 0.0 and int(vehicle.blink * 10.0) % 2 == 0:
			var sprite: AnimatedSprite2D = vehicle.sprite
			var side: float = signf(vehicle.next_lane - vehicle.lane)
			var corner: Vector2 = sprite.position + Vector2(side * vehicle.half.x * 0.8, vehicle.half.y * 0.5)
			c.draw_rect(Rect2(corner - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), Color(1.0, 0.8, 0.1))
