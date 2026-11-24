class_name BanditHuntMinigame
extends Minigame
## "Caza bandidos", inside the head of the politician of the morning bus: bandits cross his huge
## forehead towards the border on the right; aim (mouse or movement keys) and shoot (click or interact).
## Model: random walk. Every STEP_SECONDS each bandit takes one step on the grid: right with P_RIGHT,
## back with P_LEFT, up or down with P_SIDE each (a biased 2D walk; rows are bounded, it stays put at
## the edge). The drift is E[ΔX] = P_RIGHT - P_LEFT cells per step, so crossing COLUMNS cells takes
## COLUMNS / drift steps on average; the box compares it with the bandits that escaped.
## Bandits arrive as a Poisson process (rate ARRIVAL_RATE). Catching them gives energy and time.

const ENEMY_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/enemy_sprite_frames.tres")
const PORTRAIT: Texture2D = preload("res://assets/sprites/npcs/abelardo_portrait.png")
const BANDIT_LOOKS: Array[StringName] = [&"dark_street_a_right", &"dark_street_b_right", &"suspicious_gray_right"]
const CELL: float = 32.0
const ORIGIN: Vector2 = Vector2(40.0, 106.0)  # Center of cell (0, 0), below the model box.
const COLUMNS: int = 17
const ROWS: int = 7
const P_RIGHT: float = 0.5
const P_LEFT: float = 0.1
const P_SIDE: float = 0.2  # Up, and the same for down.
const STEP_SECONDS: float = 0.35
const ARRIVAL_RATE: float = 1.1
const MAX_ALIVE: int = 7
const BANDIT_HEIGHT: float = 40.0
const HIT_RADIUS: float = 20.0
const SHOT_COOLDOWN: float = 0.2
const CROSSHAIR_SPEED: float = 320.0
const TRAIL_LENGTH: int = 6
const ENERGY_BASE: float = 2.0
const ENERGY_PER_CATCH: float = 1.0
const TIME_BASE: float = 1.0
const TIME_PER_CATCH: float = 0.5
const MAX_CATCHES_PAID: int = 10

var _rng: Lcg
var _canvas: Control
var _people: Node2D
var _bandits: Array[Dictionary] = []  # {sprite, cell: Vector2i, steps, trail: Array[Vector2i]}
var _next_arrival: float = 0.3
var _step_left: float = STEP_SECONDS
var _crosshair: Vector2 = Vector2(320.0, 200.0)
var _use_mouse: bool = false
var _cooldown: float = 0.0
var _flash: float = 0.0
var _caught: int = 0
var _escaped: int = 0
var _escape_steps: Array[int] = []
var _arrived: int = 0
var _notes: Array[Dictionary] = []  # {text, position, age}


func _init() -> void:
	title = "Caza bandidos"
	instructions = "Te metiste en la cabeza de Abelardo: por su frente cruzan bandidos que buscan escaparse por la frontera de la derecha. Apunta con el ratón o con {up} {left} {down} {right} y dispara con clic o {interact}. Cada bandido hace una caminata aleatoria: casi siempre avanza, pero a veces se devuelve o se corre de lado. Cada captura te da energía y tiempo."
	model_name = "Caminata aleatoria"
	duration_seconds = 20.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	stage.add_child(_canvas)
	_people = Node2D.new()
	stage.add_child(_people)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.size = Vector2(64.0, 64.0)
	portrait.position = Vector2(SCREEN.x - 68.0, 2.0)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(portrait)
	var aim: Control = Control.new()  # Above the bandits.
	aim.size = SCREEN
	aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim.draw.connect(_draw_aim.bind(aim))
	stage.add_child(aim)
	_canvas.set_meta("aim", aim)


func _play(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	var keys: Vector2 = Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP, InputActions.MOVE_DOWN)
	if not keys.is_zero_approx():
		_use_mouse = false
		_crosshair += keys * CROSSHAIR_SPEED * delta
	elif _use_mouse:
		_crosshair = _stage.get_local_mouse_position()
	_crosshair = _crosshair.clamp(Vector2.ZERO, SCREEN)

	_next_arrival -= delta
	if _next_arrival <= 0.0:
		_next_arrival = _rng.exponential(ARRIVAL_RATE)
		if _bandits.size() < MAX_ALIVE and _time_left > 1.5:
			_spawn()
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left += STEP_SECONDS
		_step_all()
	for bandit: Dictionary in _bandits:
		var sprite: AnimatedSprite2D = bandit.sprite
		sprite.position = sprite.position.move_toward(_cell_center(bandit.cell), CELL / STEP_SECONDS * delta)
	for note: Dictionary in _notes:
		note.age += delta
	_notes = _notes.filter(func(note: Dictionary) -> bool: return note.age < 1.2)
	_canvas.queue_redraw()
	(_canvas.get_meta("aim") as Control).queue_redraw()


func _on_input(event: InputEvent) -> void:
	if not is_playing():
		return
	if event is InputEventMouseMotion:
		_use_mouse = true
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed(InputActions.INTERACT):
		_shoot()


func _spawn() -> void:
	var cell: Vector2i = Vector2i(0, _rng.index(ROWS))
	var sprite: AnimatedSprite2D = _sprite(ENEMY_FRAMES, BANDIT_LOOKS[_rng.index(BANDIT_LOOKS.size())],
		_cell_center(cell) - Vector2(CELL, 0.0), BANDIT_HEIGHT)
	sprite.offset.y += BANDIT_HEIGHT / 2.0 / sprite.scale.y  # Origin at the center of the cell.
	_people.add_child(sprite)
	_bandits.append({"sprite": sprite, "cell": cell, "steps": 0, "trail": [cell]})
	_arrived += 1


## One step of the biased random walk for every bandit (one LCG draw each).
func _step_all() -> void:
	for i: int in range(_bandits.size() - 1, -1, -1):
		var bandit: Dictionary = _bandits[i]
		var u: float = _rng.next()
		var move: Vector2i = Vector2i.RIGHT
		if u >= P_RIGHT + P_LEFT + P_SIDE:
			move = Vector2i.DOWN
		elif u >= P_RIGHT + P_LEFT:
			move = Vector2i.UP
		elif u >= P_RIGHT:
			move = Vector2i.LEFT
		var next: Vector2i = bandit.cell + move
		next.x = maxi(next.x, 0)
		if next.y < 0 or next.y >= ROWS:
			next.y = bandit.cell.y  # A wall: it stays in its row.
		bandit.cell = next
		bandit.steps += 1
		(bandit.trail as Array).append(next)
		if (bandit.trail as Array).size() > TRAIL_LENGTH:
			(bandit.trail as Array).pop_front()
		if next.x >= COLUMNS:
			_escaped += 1
			_escape_steps.append(bandit.steps)
			_add_note("¡Se escapó!", _cell_center(Vector2i(COLUMNS - 1, next.y)), Color(1.0, 0.5, 0.45))
			(bandit.sprite as Node).queue_free()
			_bandits.remove_at(i)


func _shoot() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = SHOT_COOLDOWN
	_flash = 0.08
	var best: int = -1
	var best_distance: float = HIT_RADIUS
	for i: int in _bandits.size():
		var distance: float = (_bandits[i].sprite as AnimatedSprite2D).position.distance_to(_crosshair)
		if distance <= best_distance:
			best = i
			best_distance = distance
	if best < 0:
		AudioManager.play_sfx(&"ui_move", 0.6)
		return
	var bandit: Dictionary = _bandits[best]
	_caught += 1
	AudioManager.play_sfx(&"hit", 1.0 + _caught * 0.03)
	_add_note("¡Capturado!", (bandit.sprite as AnimatedSprite2D).position, Color(1.0, 0.85, 0.3))
	var sprite: AnimatedSprite2D = bandit.sprite
	_bandits.remove_at(best)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	tween.tween_callback(sprite.queue_free)


func _add_note(text: String, at: Vector2, color: Color) -> void:
	_notes.append({"text": text, "position": at, "age": 0.0, "color": color})


func _cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL


func _drift() -> float:
	return P_RIGHT - P_LEFT


func _model_text() -> String:
	var expected: float = COLUMNS / _drift()
	var measured: String = "aún nadie cruza"
	if not _escape_steps.is_empty():
		var total: int = 0
		for steps: int in _escape_steps:
			total += steps
		measured = "medido %.1f (n = %d)" % [float(total) / _escape_steps.size(), _escape_steps.size()]
	return "p→ %.2f  p← %.2f  p↑ = p↓ %.2f · deriva E[ΔX] = p→ - p← = %.2f casilla/paso\nPasos para cruzar: teórico %.0f · %s" % [
		P_RIGHT, P_LEFT, P_SIDE, _drift(), expected, measured]


func _result() -> Dictionary:
	var expected: float = COLUMNS / _drift()
	var mean: float = 0.0
	for steps: int in _escape_steps:
		mean += steps
	mean /= maxf(_escape_steps.size(), 1.0)
	Simulation.report(Simulation.MODEL_RANDOM_WALK, "Caza bandidos: deriva %.2f, cruce teórico %.0f pasos vs medido %.1f (n = %d); %d capturados" % [
		_drift(), expected, mean, _escape_steps.size(), _caught])
	var paid: int = mini(_caught, MAX_CATCHES_PAID)
	var summary: String = "Capturaste %d de %d bandidos (se escaparon %d)" % [_caught, _arrived, _escaped]
	return {"money": 0.0, "energy": ENERGY_BASE + ENERGY_PER_CATCH * paid,
		"time": TIME_BASE + TIME_PER_CATCH * paid, "summary": summary}


## Inside his head: a warm forehead with a faint grid, the entry on the left and the border on the right.
func _draw_scene() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("e8b89a"))
	for i: int in 9:  # Folds of the thoughts.
		var center: Vector2 = Vector2(60.0 + i * 70.0, 70.0 + (i % 3) * 110.0)
		c.draw_arc(center, 40.0 + (i % 2) * 14.0, 0.3, 2.8, 18, Color(0.85, 0.6, 0.55, 0.55), 3.0)
	var top_left: Vector2 = _cell_center(Vector2i.ZERO) - Vector2(CELL, CELL) / 2.0
	var area: Rect2 = Rect2(top_left, Vector2(COLUMNS * CELL, ROWS * CELL))
	c.draw_rect(area, Color(1.0, 1.0, 1.0, 0.12))
	for x: int in COLUMNS + 1:
		c.draw_line(Vector2(area.position.x + x * CELL, area.position.y), Vector2(area.position.x + x * CELL, area.end.y), Color(0.6, 0.35, 0.3, 0.25))
	for y: int in ROWS + 1:
		c.draw_line(Vector2(area.position.x, area.position.y + y * CELL), Vector2(area.end.x, area.position.y + y * CELL), Color(0.6, 0.35, 0.3, 0.25))
	var flag: Array[Color] = [Color("f6cc1e"), Color("1e46a0"), Color("c82828")]
	for i: int in 3:  # The border, in the colors of the flag.
		c.draw_rect(Rect2(area.end.x + i * 6.0, area.position.y, 6.0, area.size.y), flag[i])
	var font: Font = c.get_theme_default_font()
	c.draw_string(font, Vector2(area.end.x - 40.0, area.end.y + 16.0), "FRONTERA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6a2a20"))
	c.draw_string(font, Vector2(area.position.x, area.end.y + 16.0), "Capturados: %d   Escapados: %d" % [_caught, _escaped], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("3a1a14"))
	for bandit: Dictionary in _bandits:  # Recent path of each walk.
		var points: PackedVector2Array = []
		for cell: Vector2i in bandit.trail:
			points.append(_cell_center(cell))
		if points.size() >= 2:
			c.draw_polyline(points, Color(0.4, 0.1, 0.1, 0.35), 2.0)
	for note: Dictionary in _notes:
		var t: float = note.age / 1.2
		var color: Color = note.color
		color.a = 1.0 - t
		c.draw_string(font, note.position + Vector2(-30.0, -26.0 - 20.0 * t), note.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _draw_aim(c: Control) -> void:
	if not is_playing():
		return
	var color: Color = Color(1.0, 1.0, 1.0) if _flash > 0.0 else Color(0.7, 0.05, 0.05)
	c.draw_arc(_crosshair, 12.0, 0.0, TAU, 24, color, 2.0)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		c.draw_line(_crosshair + direction * 6.0, _crosshair + direction * 16.0, color, 2.0)
	if _flash > 0.0:
		c.draw_circle(_crosshair, 6.0, Color(1.0, 0.95, 0.6))
