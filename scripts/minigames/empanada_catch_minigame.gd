class_name EmpanadaCatchMinigame
extends Minigame
## "Atrapa las empanadas": the vendor tosses empanadas (Poisson arrivals, λ = TOSS_RATE); move with
## A/D to catch them. Each one caught gives a bit more energy.
## Model: Monte Carlo. Where an empanada lands is a sample of a distribution the player does not see
## (a mixture of two normals: the vendor's two favorite throws, drawn with Box-Muller). Every landing
## is added to a histogram at the bottom; with more samples it estimates the distribution, so the
## player learns where to stand. The box shows n, the estimated mean and the busiest zone.

const NPC_FRAMES: SpriteFrames = preload("res://assets/sprites/npcs/npc_sprite_frames.tres")
const ITEM_FRAMES: SpriteFrames = preload("res://assets/sprites/items/items_sprite_frames.tres")
const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_sprite_frames.tres")
const TOSS_RATE: float = 1.6
const GRAVITY: float = 260.0
const PLAYER_SPEED: float = 280.0
const PLAYER_Y: float = 320.0
const CATCH_RADIUS: float = 22.0
const MIN_X: float = 60.0
const MAX_X: float = 580.0
const ENERGY_PER_CATCH: float = 1.5
const MAX_CATCHES_PAID: int = 8
## Hidden landing distribution: two normals (mean x, standard deviation, weight).
const THROWS: Array = [[200.0, 45.0, 0.6], [470.0, 35.0, 0.4]]
const BINS: int = 13
const HANDS_Y: float = 272.0
const START_SPEED: float = -60.0

var _player: AnimatedSprite2D
var _vendor: AnimatedSprite2D
var _falling: Array[Dictionary] = []  # {sprite, speed}
var _next_toss: float = 0.5
var _tossed: int = 0
var _caught: int = 0
var _canvas: Control
var _food: Node2D
var _rng: Lcg
var _histogram: Array[int] = []
var _landings: Array[float] = []


func _init() -> void:
	title = "Atrapa las empanadas"
	instructions = "El vendedor te lanza las empanadas calientes. Muévete con {left} y {right} para atraparlas. El vendedor tiene sus lanzamientos favoritos: abajo se va armando el histograma de dónde caen (Monte Carlo). Úsalo para pararte donde más caen."
	model_name = "Monte Carlo"
	duration_seconds = 12.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_histogram.resize(BINS)
	_histogram.fill(0)
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	stage.add_child(_canvas)
	var people: Node2D = Node2D.new()
	stage.add_child(people)
	_vendor = _sprite(NPC_FRAMES, &"empanada_vendor", Vector2(320.0, 146.0), 80.0)
	people.add_child(_vendor)
	_food = Node2D.new()
	stage.add_child(_food)
	_player = _sprite(PLAYER_FRAMES, &"idle_up", Vector2(320.0, PLAYER_Y), 72.0)
	people.add_child(_player)


func _play(delta: float) -> void:
	var input: float = Input.get_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT)
	_player.position.x = clampf(_player.position.x + input * PLAYER_SPEED * delta, MIN_X, MAX_X)
	_vendor.position.x = 320.0 + sin(_phase_time * 1.7) * 160.0

	_next_toss -= delta
	if _next_toss <= 0.0 and _time_left > 1.2:
		_toss()
		_next_toss = _rng.exponential(TOSS_RATE)

	var hands: Vector2 = _player.position + Vector2(0.0, -48.0)
	for i: int in range(_falling.size() - 1, -1, -1):
		var item: Dictionary = _falling[i]
		var sprite: AnimatedSprite2D = item.sprite
		item.speed += GRAVITY * delta
		sprite.position += Vector2(item.drift, item.speed) * delta
		if not item.recorded and sprite.position.y >= HANDS_Y:
			item.recorded = true
			_record(sprite.position.x)
		sprite.rotation += delta * 4.0
		if sprite.position.distance_to(hands) < CATCH_RADIUS:
			_caught += 1
			AudioManager.play_sfx(&"pickup", 1.0 + _caught * 0.05)
			sprite.queue_free()
			_falling.remove_at(i)
		elif sprite.position.y > SCREEN.y + 20.0:
			sprite.queue_free()
			_falling.remove_at(i)
	_canvas.queue_redraw()


func _toss() -> void:
	var sprite: AnimatedSprite2D = _sprite(ITEM_FRAMES, &"empanada", _vendor.position + Vector2(0.0, -40.0), 26.0)
	sprite.offset = Vector2.ZERO
	_food.add_child(sprite)
	var target_x: float = clampf(_sample_landing(), MIN_X, MAX_X)
	# Time to fall from the hand to the player's hands: y0 + v0 t + g t^2 / 2 = HANDS_Y.
	var drop: float = HANDS_Y - sprite.position.y
	var fall_time: float = (-START_SPEED + sqrt(START_SPEED * START_SPEED + 2.0 * GRAVITY * drop)) / GRAVITY
	_falling.append({"sprite": sprite, "speed": START_SPEED, "drift": (target_x - sprite.position.x) / fall_time, "recorded": false})
	_tossed += 1


## One Monte Carlo sample: pick a throw by its weight, then a normal value (Box-Muller).
func _sample_landing() -> float:
	var throw: Array = THROWS[0] if _rng.next() < THROWS[0][2] else THROWS[1]
	var u1: float = maxf(_rng.next(), 1e-6)
	var u2: float = _rng.next()
	var z: float = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return throw[0] + throw[1] * z


func _record(x: float) -> void:
	_landings.append(x)
	var bin: int = clampi(int((x - MIN_X) / (MAX_X - MIN_X) * BINS), 0, BINS - 1)
	_histogram[bin] += 1


func _estimated_mean() -> float:
	var total: float = 0.0
	for x: float in _landings:
		total += x
	return total / maxf(_landings.size(), 1.0)


func _busiest_bin() -> int:
	var best: int = 0
	for i: int in BINS:
		if _histogram[i] > _histogram[best]:
			best = i
	return best


func _model_text() -> String:
	if _landings.is_empty():
		return "Aún no hay muestras"
	var width: float = (MAX_X - MIN_X) / BINS
	var zone: float = MIN_X + (_busiest_bin() + 0.5) * width
	var theory: float = THROWS[0][0] * THROWS[0][2] + THROWS[1][0] * THROWS[1][2]
	return "n = %d muestras · media estimada %.0f (real %.0f)\nZona más frecuente: x = %.0f" % [
		_landings.size(), _estimated_mean(), theory, zone]


func _result() -> Dictionary:
	var theory: float = THROWS[0][0] * THROWS[0][2] + THROWS[1][0] * THROWS[1][2]
	Simulation.report(Simulation.MODEL_MONTE_CARLO, "Empanadas: %d muestras de caída, media estimada %.0f vs teórica %.0f; %d atrapadas" % [
		_landings.size(), _estimated_mean(), theory, _caught])
	var paid: int = mini(_caught, MAX_CATCHES_PAID)
	var summary: String = "Atrapaste %d de %d empanadas" % [_caught, _tossed]
	return {"money": 0.0, "energy": ENERGY_PER_CATCH * paid, "time": 0.0, "summary": summary}


func _draw_scene() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("b8b0a0"))  # Sidewalk.
	c.draw_rect(Rect2(0.0, 0.0, SCREEN.x, 60.0), Color("e8a85c"))  # Shop fronts.
	c.draw_rect(Rect2(200.0, 148.0, 240.0, 30.0), Color("d35400"))  # Stand.
	c.draw_rect(Rect2(200.0, 144.0, 240.0, 6.0), Color("f39c12"))
	for x: float in range(0, int(SCREEN.x), 64):
		c.draw_line(Vector2(x, 200.0), Vector2(x, SCREEN.y), Color(0.0, 0.0, 0.0, 0.08))
	if is_playing():
		_draw_histogram(c)
		c.draw_string(c.get_theme_default_font(), Vector2(20.0, 340.0), "Atrapadas: %d" % _caught, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)


## Where the empanadas have landed so far: the Monte Carlo estimate of the distribution.
func _draw_histogram(c: Control) -> void:
	var width: float = (MAX_X - MIN_X) / BINS
	var tallest: int = 1
	for count: int in _histogram:
		tallest = maxi(tallest, count)
	for i: int in BINS:
		var height: float = 44.0 * _histogram[i] / tallest
		var x: float = MIN_X + i * width
		c.draw_rect(Rect2(x + 1.0, SCREEN.y - 4.0 - height, width - 2.0, height), Color(0.85, 0.45, 0.1, 0.55))
	c.draw_line(Vector2(MIN_X, SCREEN.y - 4.0), Vector2(MAX_X, SCREEN.y - 4.0), Color(0.0, 0.0, 0.0, 0.4), 1.0)
	if not _landings.is_empty():
		var mean_x: float = _estimated_mean()
		c.draw_line(Vector2(mean_x, SCREEN.y - 56.0), Vector2(mean_x, SCREEN.y - 4.0), Color(0.2, 0.2, 0.8, 0.8), 2.0)
