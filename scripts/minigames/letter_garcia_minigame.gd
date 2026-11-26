class_name LetterGarciaMinigame
extends Minigame
## "La carta a García": the boss puts you at the mail desk. Letters keep arriving and you are the one
## who serves them: read who each one is for and send it to its mailbox (up García, right Gómez,
## down Díaz). The golden ones are "la carta a García": urgent.
## Model: M/M/1 queue with the player as the server. Letters arrive as a Poisson process (rate
## ARRIVAL_RATE); the service rate μ is how fast the player dispatches, measured live as
## μ̂ = served / busy time. With ρ = λ / μ̂ the theory gives Lq = ρ² / (1 - ρ) and Wq = Lq / λ; the box
## compares them with the line actually observed (time average of the people waiting, mean wait).
## A human server is not exponential (it is an M/G/1), so expect some difference. When the line
## reaches MAX_QUEUE new letters overflow and are lost.

const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_sprite_frames.tres")
const PORTRAIT: Texture2D = preload("res://assets/sprites/npcs/boss_letter_portrait.png")
const ARRIVAL_RATE: float = 1.2
const MAX_QUEUE: int = 12
## Recipients: name, the action that sends a letter there, chance of a letter being for them.
const NAMES: PackedStringArray = ["García", "Gómez", "Díaz"]
const ACTIONS: Array[StringName] = [InputActions.MOVE_UP, InputActions.MOVE_RIGHT, InputActions.MOVE_DOWN]
const SHARES: PackedFloat32Array = [0.35, 0.35, 0.30]
const GARCIA: int = 0
const DESK: Vector2 = Vector2(330.0, 232.0)
## Up, right and down of the desk, like the keys that send there.
const MAILBOXES: Array[Vector2] = [Vector2(330.0, 118.0), Vector2(520.0, 226.0), Vector2(330.0, 322.0)]
const MAILBOX_SIZE: Vector2 = Vector2(96.0, 40.0)
const MAILBOX_COLORS: Array[Color] = [Color("c8961e"), Color("7a4a2c"), Color("2c5a7a")]
const ENVELOPE: Vector2 = Vector2(22.0, 14.0)
const QUEUE_SPACING: float = 20.0
const FLY_SECONDS: float = 0.35
const HISTORY_SECONDS: float = 0.25
const HISTORY_SIZE: int = 80
const MONEY_PER_LETTER: float = 0.25
const MAX_MONEY: float = 4.0
const TIME_PER_GARCIA: float = 1.0
const MAX_TIME: float = 3.0
const ENERGY_PER_ERROR: float = -0.5
const MAX_ENERGY_LOSS: float = -3.0
const GOLD: Color = Color("e8b830")
const PAPER: Color = Color("f2ead8")

var _rng: Lcg
var _canvas: Control
var _clerk: AnimatedSprite2D
## The line: front first. {dest, arrived}
var _queue: Array[Dictionary] = []
var _clock: float = 0.0
var _next_arrival: float = 0.0
var _front_since: float = 0.0
var _busy: float = 0.0
var _area_waiting: float = 0.0  # Integral of the people waiting (not in service) over time.
var _waits: PackedFloat32Array = []
var _served: int = 0
var _correct: int = 0
var _garcia_delivered: int = 0
var _errors: int = 0
var _overflow: int = 0
var _arrived: int = 0
var _flying: Array[Dictionary] = []  # {from, to, age, gold, ok}
var _history: Array[int] = []
var _sample_left: float = 0.0


func _init() -> void:
	title = "La carta a García"
	instructions = "El jefe te pone en el escritorio de correo: las cartas llegan sin parar y tú las despachas. Mira para quién es la primera de la fila y envíala: {up} García, {right} Gómez, {down} Díaz. Las doradas son «la carta a García». Eres el servidor de una cola M/M/1: tu ritmo es μ. Si vas más lento que las llegadas (ρ = λ/μ cerca de 1), la fila crece."
	model_name = "Colas M/M/1 (tú eres el servidor)"
	duration_seconds = 20.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_next_arrival = _rng.exponential(ARRIVAL_RATE)
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	stage.add_child(_canvas)
	_clerk = _sprite(PLAYER_FRAMES, &"idle_down", DESK, 50.0)  # Behind the counter, over the letter.
	stage.add_child(_clerk)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.size = Vector2(64.0, 64.0)
	portrait.position = Vector2(SCREEN.x - 68.0, 2.0)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(portrait)


func _play(delta: float) -> void:
	_advance(delta)
	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left += HISTORY_SECONDS
		_history.append(_queue.size())
		if _history.size() > HISTORY_SIZE:
			_history.pop_front()
	for letter: Dictionary in _flying:
		letter.age += delta
	_flying = _flying.filter(func(letter: Dictionary) -> bool: return letter.age < FLY_SECONDS)
	_canvas.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if not is_playing():
		return
	for i: int in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[i]):
			_dispatch(i)
			return


## Time passes: letters arrive (Poisson) and the areas of the queue grow. Separate from _play so the
## self-test can run the queue without drawing.
func _advance(delta: float) -> void:
	_clock += delta
	_area_waiting += maxi(_queue.size() - 1, 0) * delta
	if not _queue.is_empty():
		_busy += delta
	_next_arrival -= delta
	while _next_arrival <= 0.0:
		_next_arrival += _rng.exponential(ARRIVAL_RATE)
		_arrive()


func _arrive() -> void:
	_arrived += 1
	if _queue.size() >= MAX_QUEUE:
		_overflow += 1
		return
	_queue.append({"dest": _pick_recipient(), "arrived": _clock})
	if _queue.size() == 1:  # Nobody ahead: its service starts now, with no wait.
		_front_since = _clock
		_waits.append(0.0)


## The player sends the front letter to the mailbox [param choice]. Its service ends now.
func _dispatch(choice: int) -> void:
	if _queue.is_empty():
		return
	var letter: Dictionary = _queue.pop_front()
	_served += 1
	var ok: bool = letter.dest == choice
	if ok:
		_correct += 1
		if letter.dest == GARCIA:
			_garcia_delivered += 1
		AudioManager.play_sfx(&"coin" if letter.dest == GARCIA else &"ui_confirm")
	else:
		_errors += 1
		AudioManager.play_sfx(&"decision_bad")
	_flying.append({"from": DESK + Vector2(0.0, 13.0), "to": MAILBOXES[choice], "age": 0.0,
		"gold": letter.dest == GARCIA, "ok": ok})
	if not _queue.is_empty():
		_front_since = _clock
		_waits.append(_clock - float(_queue[0].arrived))


func _pick_recipient() -> int:
	var u: float = _rng.next()
	var cumulative: float = 0.0
	for i: int in SHARES.size():
		cumulative += SHARES[i]
		if u < cumulative:
			return i
	return SHARES.size() - 1


## μ̂: letters served per second of work (the time with letters at the desk).
func measured_service_rate() -> float:
	return _served / _busy if _busy > 0.0 else 0.0


func measured_lq() -> float:
	return _area_waiting / _clock if _clock > 0.0 else 0.0


func measured_wq() -> float:
	if _waits.is_empty():
		return 0.0
	var total: float = 0.0
	for wait: float in _waits:
		total += wait
	return total / _waits.size()


## M/M/1 with the measured μ: {rho, lq, wq}; lq and wq are INF when ρ >= 1.
func theory() -> Dictionary:
	var mu: float = measured_service_rate()
	if mu <= 0.0:
		return {"rho": 0.0, "lq": 0.0, "wq": 0.0}
	var rho: float = ARRIVAL_RATE / mu
	if rho >= 1.0:
		return {"rho": rho, "lq": INF, "wq": INF}
	var lq: float = rho * rho / (1.0 - rho)
	return {"rho": rho, "lq": lq, "wq": lq / ARRIVAL_RATE}


func _model_text() -> String:
	var t: Dictionary = theory()
	var mu: float = measured_service_rate()
	var mu_text: String = "aún sin medir" if mu <= 0.0 else "%.2f cartas/s" % mu
	var theory_text: String = "ρ ≥ 1: la fila crece sin parar" if t.rho >= 1.0 else \
		"En estado estable: Lq %.2f · medido %.2f   Wq %.2f s · medido %.2f s" % [t.lq, measured_lq(), t.wq, measured_wq()]
	return "λ = %.1f cartas/s · tu ritmo μ̂ = %s · ρ = λ/μ̂ = %.2f\n%s" % [ARRIVAL_RATE, mu_text, t.rho, theory_text]


func _result() -> Dictionary:
	var t: Dictionary = theory()
	Simulation.report(Simulation.MODEL_QUEUE, "Carta a García: λ %.1f, μ̂ %.2f, ρ %.2f; Lq medido %.2f vs teórico %s; %d despachadas, %d desbordadas" % [
		ARRIVAL_RATE, measured_service_rate(), t.rho, measured_lq(), "∞" if t.lq == INF else "%.2f" % t.lq, _served, _overflow])
	var summary: String = "Despachaste %d cartas (%d a García), %d al buzón equivocado y %d se desbordaron" % [
		_correct, _garcia_delivered, _errors, _overflow]
	return {"money": minf(_correct * MONEY_PER_LETTER, MAX_MONEY),
		"energy": maxf(_errors * ENERGY_PER_ERROR, MAX_ENERGY_LOSS),
		"time": minf(_garcia_delivered * TIME_PER_GARCIA, MAX_TIME), "summary": summary}


func _draw_scene() -> void:
	var c: Control = _canvas
	var font: Font = c.get_theme_default_font()
	# The post office: a warm wall with a wainscot and a tiled floor.
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("d9c7a3"))
	c.draw_rect(Rect2(0.0, 150.0, SCREEN.x, 14.0), Color("8a5a3a"))
	for x: int in range(0, int(SCREEN.x), 24):
		c.draw_line(Vector2(x, 164.0), Vector2(x, 196.0), Color(0.45, 0.3, 0.2, 0.35), 1.0)
	c.draw_rect(Rect2(0.0, 164.0, SCREEN.x, 32.0), Color(0.55, 0.36, 0.22, 0.35))
	for y: int in range(196, int(SCREEN.y), 20):
		for x: int in range(0, int(SCREEN.x), 20):
			if ((x + y) / 20) % 2 == 0:
				c.draw_rect(Rect2(x, y, 20.0, 20.0), Color(0.0, 0.0, 0.0, 0.07))
	c.draw_rect(Rect2(0.0, 196.0, SCREEN.x, SCREEN.y - 196.0), Color(0.25, 0.22, 0.2, 0.25))
	c.draw_string(font, Vector2(20.0, 112.0), "CORREO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8a5a3a"))
	# Arrows from the desk to the mailboxes.
	for i: int in MAILBOXES.size():
		var direction: Vector2 = (MAILBOXES[i] - DESK).normalized()
		var tip: Vector2 = DESK + direction * 52.0
		var side: Vector2 = direction.orthogonal() * 6.0
		c.draw_colored_polygon(PackedVector2Array([tip, tip - direction * 10.0 + side, tip - direction * 10.0 - side]),
			Color(1.0, 1.0, 1.0, 0.55))
	for i: int in NAMES.size():  # Mailboxes: name and key on the front.
		var rect: Rect2 = Rect2(MAILBOXES[i] - MAILBOX_SIZE / 2.0, MAILBOX_SIZE)
		c.draw_rect(rect, MAILBOX_COLORS[i])
		c.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), MAILBOX_COLORS[i].lightened(0.25))
		c.draw_rect(rect, Color(0.12, 0.08, 0.05), false, 2.0)
		c.draw_rect(Rect2(rect.get_center() + Vector2(-26.0, -12.0), Vector2(52.0, 5.0)), Color(0.1, 0.07, 0.05))
		c.draw_string(font, rect.position + Vector2(0.0, 34.0), "[%s] %s" % [Settings.key_name(ACTIONS[i]), NAMES[i]],
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color.WHITE)
	# The conveyor with the line, then the counter.
	c.draw_rect(Rect2(Vector2(14.0, DESK.y + 2.0), Vector2(DESK.x - 64.0, 10.0)), Color("2a2a30"))
	for x: int in range(18, int(DESK.x) - 54, 12):
		c.draw_circle(Vector2(x, DESK.y + 7.0), 3.0, Color("44444c"))
	for i: int in range(_queue.size() - 1, 0, -1):
		var at: Vector2 = Vector2(DESK.x - 62.0 - (i - 1) * QUEUE_SPACING, DESK.y - 6.0)
		_draw_envelope(c, at, int(_queue[i].dest) == GARCIA, 1.0)
	c.draw_rect(Rect2(DESK + Vector2(-46.0, 0.0), Vector2(92.0, 26.0)), Color("9a6b4f"))
	c.draw_rect(Rect2(DESK + Vector2(-46.0, 0.0), Vector2(92.0, 5.0)), Color("c08a64"))
	c.draw_rect(Rect2(DESK + Vector2(-46.0, 0.0), Vector2(92.0, 26.0)), Color(0.25, 0.15, 0.1), false, 2.0)
	if not _queue.is_empty():  # The letter being served, big on the counter, with its recipient.
		var front: Dictionary = _queue[0]
		var gold: bool = int(front.dest) == GARCIA
		_draw_envelope(c, DESK + Vector2(0.0, 13.0), gold, 1.8)
		var label: String = "Para: %s" % NAMES[front.dest]
		c.draw_rect(Rect2(DESK + Vector2(-56.0, 30.0), Vector2(112.0, 20.0)), Color(0.05, 0.05, 0.08, 0.8))
		c.draw_string(font, DESK + Vector2(-56.0, 45.0), label, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 15,
			GOLD if gold else Color.WHITE)
	for letter: Dictionary in _flying:
		var t: float = letter.age / FLY_SECONDS
		_draw_envelope(c, (letter.from as Vector2).lerp(letter.to, t), letter.gold, 1.4 - 0.4 * t)
		if t > 0.5:
			c.draw_string(font, (letter.to as Vector2) + Vector2(MAILBOX_SIZE.x / 2.0 + 4.0, 6.0), "✓" if letter.ok else "✗",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.2, 0.8, 0.3) if letter.ok else Color(0.9, 0.2, 0.2))
	c.draw_string(font, Vector2(14.0, DESK.y + 32.0), "En fila: %d / %d" % [_queue.size(), MAX_QUEUE],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("3a2418"))
	c.draw_string(font, Vector2(14.0, DESK.y + 48.0), "Despachadas %d · equivocadas %d · desbordadas %d" % [_correct, _errors, _overflow],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3a2418"))
	_draw_plot(c, font)


## Airmail envelope; the letter to García is golden with a wax seal.
func _draw_envelope(c: Control, center: Vector2, gold: bool, size: float) -> void:
	var extent: Vector2 = ENVELOPE * size
	var rect: Rect2 = Rect2(center - extent / 2.0, extent)
	var ink: Color = Color(0.25, 0.18, 0.12)
	c.draw_rect(rect, GOLD if gold else PAPER)
	if not gold:
		for x: float in range(int(rect.position.x), int(rect.end.x), int(6.0 * size)):
			c.draw_rect(Rect2(Vector2(x, rect.position.y), Vector2(3.0 * size, 2.0)), Color("c0392b"))
			c.draw_rect(Rect2(Vector2(x + 3.0 * size, rect.end.y - 2.0), Vector2(3.0 * size, 2.0)), Color("2c5a9a"))
	c.draw_rect(rect, ink, false, 1.0)
	c.draw_line(rect.position, rect.get_center(), ink, 1.0)
	c.draw_line(Vector2(rect.end.x, rect.position.y), rect.get_center(), ink, 1.0)
	if gold:
		c.draw_circle(rect.get_center() + Vector2(0.0, 1.0), 2.5 * size, Color("9a1a1a"))


## N(t): letters at the desk over time, against the theoretical L = ρ / (1 - ρ).
func _draw_plot(c: Control, font: Font) -> void:
	var box: Rect2 = Rect2(Vector2(SCREEN.x - 196.0, 292.0), Vector2(188.0, 60.0))
	c.draw_rect(box, Color(0.05, 0.08, 0.15, 0.85))
	c.draw_string(font, box.position + Vector2(5.0, 12.0), "N(t): cartas en el escritorio", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	var plot: Rect2 = Rect2(box.position + Vector2(5.0, 16.0), box.size - Vector2(10.0, 20.0))
	var top: float = float(MAX_QUEUE)
	var t: Dictionary = theory()
	if t.rho > 0.0 and t.rho < 1.0:
		var l_theory: float = t.rho / (1.0 - t.rho)
		var y: float = plot.end.y - plot.size.y * minf(l_theory / top, 1.0)
		c.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1.0, 0.85, 0.3, 0.8), 1.0)
	if _history.size() >= 2:
		var points: PackedVector2Array = []
		for i: int in _history.size():
			points.append(Vector2(plot.position.x + plot.size.x * i / float(HISTORY_SIZE - 1),
				plot.end.y - plot.size.y * _history[i] / top))
		c.draw_polyline(points, Color(0.45, 0.7, 1.0), 2.0)
