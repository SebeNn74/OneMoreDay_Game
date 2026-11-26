class_name QueueScreen
extends CanvasLayer
## Full screen view of an M/M/1 queue (model 1) the player joined: the line, the server (the bus
## door or the window), the theoretical metrics and the live state, and a plot of N(t).
## Discrete-event logic in real time: arrivals with exponential gaps (λ) join behind the player;
## the person at the front is served for an exponential time (μ) and leaves. The wait is the time
## until the player reaches the front. One model unit = one "minute" = SECONDS_PER_UNIT seconds;
## holding E fast-forwards. Emits finished(wait) after the player reads the result.

signal finished(wait: float)

const DRAW_LAYER: int = 30
const SCREEN: Vector2 = Vector2(640.0, 360.0)
## Real seconds per minute of the model: slow enough to watch arrivals and services one by one.
const SECONDS_PER_UNIT: float = 2.0
## Floating notes ("llegó alguien", "atendido") rise this many px and last this long.
const NOTE_SECONDS: float = 1.6
const NOTE_RISE: float = 28.0
const FAST_FORWARD: float = 4.0
const CROWD_FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/enemy_sprite_frames.tres")
const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_sprite_frames.tres")
const NPC_FRAMES: SpriteFrames = preload("res://assets/sprites/npcs/npc_sprite_frames.tres")
const CROWD_ANIMATIONS: Array[StringName] = [&"crowd_a_right", &"crowd_b_right", &"crowd_c_right"]
const FRONT_X: float = 452.0
const FLOOR_Y: float = 268.0
const SPACING: float = 34.0
const PERSON_HEIGHT: float = 56.0
const WALK_SPEED: float = 240.0
const MAX_VISIBLE_BEHIND: int = 4
const HISTORY_SIZE: int = 80
const SAMPLE_UNITS: float = 0.1
const ACCENT: Color = Color(1.0, 0.85, 0.3)
const QUEUE_COLOR: Color = Color(0.45, 0.7, 1.0)

var _config: QueueConfig
var _is_bus: bool = true
var _ahead: int = 0  # People in front of the player, the one being served included.
var _behind: int = 0
var _waited: float = 0.0
var _service_left: float = 0.0
var _next_arrival: float = 0.0
var _sample_left: float = 0.0
var _history: Array[int] = []
var _served: int = 0
var _done: bool = false
## After reaching the front the player is served too (an exponential service of rate μ).
## The cost of the queue stays the wait in line (Wq); the service is shown so W = Wq + 1/μ is visible.
var _being_served: bool = false
var _my_service: float = 0.0
var _service_total: float = 0.0  # Service time drawn for whoever is at the front now.
var _notes: Array[Dictionary] = []  # {text, position, age}
var _result_shown: bool = false
var _rng: Lcg
var _people: Array[AnimatedSprite2D] = []  # In line order: front first. The player is one of them.
var _player: AnimatedSprite2D
var _canvas: Control
var _stats: Label
var _big: Label


## Opens the screen for [param config] with [param ahead] people already in line.
static func open(parent: Node, config: QueueConfig, ahead: int) -> QueueScreen:
	var screen: QueueScreen = QueueScreen.new()
	screen._config = config
	screen._ahead = ahead
	parent.add_child(screen)
	return screen


func _ready() -> void:
	layer = DRAW_LAYER
	_rng = Simulation.rng
	_is_bus = _config.display_name.begins_with("Paradero")
	_service_left = _rng.exponential(_config.service_rate)
	_service_total = _service_left
	_next_arrival = _rng.exponential(_config.arrival_rate)
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	add_child(_canvas)
	var people: Node2D = Node2D.new()
	add_child(people)
	if not _is_bus:
		people.add_child(_sprite(NPC_FRAMES, &"supervisor", Vector2(FRONT_X + 78.0, FLOOR_Y - 18.0), 60.0))
	for i: int in _ahead:
		var person: AnimatedSprite2D = _person()
		person.position = Vector2(_slot_x(i), FLOOR_Y)
		people.add_child(person)
		_people.append(person)
	_player = _sprite(PLAYER_FRAMES, &"walk_right", Vector2(_slot_x(_ahead) - 90.0, FLOOR_Y), PERSON_HEIGHT)
	people.add_child(_player)
	_people.append(_player)
	_stats = _label(12)
	_stats.position = Vector2(6.0, 6.0)
	add_child(_stats)
	_big = _label(30)
	_big.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_big.add_theme_constant_override("outline_size", 6)
	_big.add_theme_color_override("font_outline_color", Color.BLACK)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.size = Vector2(SCREEN.x, 40.0)
	_big.position = Vector2(0.0, 150.0)
	add_child(_big)
	_record_sample()
	Simulation.report(Simulation.MODEL_QUEUE, "%s: te unes a la fila con %d delante (Wq teórico %.2f)" % [
		_config.display_name, _ahead, QueueModel.mean_wait(_config)])


func _process(delta: float) -> void:
	if _result_shown:
		return
	var speed: float = FAST_FORWARD if Input.is_action_pressed(InputActions.INTERACT) else 1.0
	var dt: float = delta * speed / SECONDS_PER_UNIT
	if not _done:
		_step(dt)
	_move_people(delta * speed)
	for note: Dictionary in _notes:
		note.age += delta
	_notes = _notes.filter(func(note: Dictionary) -> bool: return note.age < NOTE_SECONDS)
	_update_stats()
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _result_shown and event.is_action_pressed(InputActions.INTERACT):
		get_viewport().set_input_as_handled()
		if GameManager.current_state == GameState.Type.DIALOG:
			GameManager.change_state(GameState.Type.PLAYING)
		finished.emit(_waited)
		queue_free()


## One slice of the M/M/1 process: arrivals behind, service at the front.
func _step(dt: float) -> void:
	if _being_served:
		_my_service += dt
	else:
		_waited += dt
	_next_arrival -= dt
	if _next_arrival <= 0.0:
		_next_arrival += _rng.exponential(_config.arrival_rate)
		_behind += 1
		var last_slot: int = _people.size() + mini(_behind, MAX_VISIBLE_BEHIND) - 1
		_add_note("+1 llegó (λ)", Vector2(maxf(_slot_x(last_slot), 40.0), FLOOR_Y - 70.0))
	_service_left -= dt
	if _service_left <= 0.0:
		_service_left += _rng.exponential(_config.service_rate)
		_service_total = _service_left
		if _being_served:
			_finish_my_service()
		elif _ahead > 0:
			_add_note("atendido (μ)", Vector2(FRONT_X, FLOOR_Y - 80.0))
			_serve_front()
	_sample_left -= dt
	if _sample_left <= 0.0:
		_sample_left += SAMPLE_UNITS
		_record_sample()
	if _ahead == 0 and not _being_served and not _done:
		_being_served = true  # At the front: the service of the player starts now.
		_big.text = "¡Te toca!"
		AudioManager.play_sfx(&"go")
		get_tree().create_timer(0.8).timeout.connect(func() -> void: _big.text = "")


func _finish_my_service() -> void:
	_done = true
	_add_note("atendido (μ)", Vector2(FRONT_X, FLOOR_Y - 80.0))
	AudioManager.play_sfx(&"ui_confirm")
	get_tree().create_timer(0.6).timeout.connect(_show_result)


func _add_note(text: String, at: Vector2) -> void:
	_notes.append({"text": text, "position": at, "age": 0.0})


func _serve_front() -> void:
	_ahead -= 1
	_served += 1
	var leaving: AnimatedSprite2D = _people.pop_front()
	var tween: Tween = create_tween()
	tween.tween_property(leaving, "position", leaving.position + Vector2(70.0, -10.0), 0.5)
	tween.parallel().tween_property(leaving, "modulate:a", 0.0, 0.5)
	tween.tween_callback(leaving.queue_free)
	AudioManager.play_sfx(&"ui_move", 0.8)


func _record_sample() -> void:
	_history.append(_ahead + 1 + _behind)  # People in the system: the player counts too.
	if _history.size() > HISTORY_SIZE:
		_history.pop_front()


func _show_result() -> void:
	_result_shown = true
	_big.text = ""
	Simulation.record_queue_wait(_config, _waited)
	var panel: Label = _label(14)
	var rho: float = QueueModel.utilization(_config)
	var verdict: String = "Más que el promedio: así es la fila."
	if _waited < 0.05:
		verdict = "No había fila: eso pasa con probabilidad P(0) = 1 - ρ = %.2f." % (1.0 - rho)
	elif _waited < QueueModel.mean_wait(_config):
		verdict = "Menos que el promedio: buena suerte."
	panel.text = "En la fila: %.1f min  (Wq teórico %.1f)\nAtención: %.1f min  (1/μ teórico %.1f)\n%s\n[%s] Seguir" % [
		_waited, QueueModel.mean_wait(_config), _my_service, 1.0 / _config.service_rate, verdict,
		Settings.key_name(InputActions.INTERACT)]
	panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(panel)
	panel.reset_size()
	panel.position = (SCREEN - panel.size) / 2.0 + Vector2(0.0, -40.0)


## People left in line behind the player when they leave (to sync the line on the map).
func people_left() -> int:
	return _behind


func _move_people(delta: float) -> void:
	for i: int in _people.size():
		var person: AnimatedSprite2D = _people[i]
		var target: float = _slot_x(i)
		person.position.x = move_toward(person.position.x, target, WALK_SPEED * delta)
		var walking: bool = absf(person.position.x - target) > 1.0
		if person == _player:
			var animation: StringName = &"walk_right" if walking else &"idle_right"
			if _player.animation != animation:
				_player.play(animation)


func _slot_x(index: int) -> float:
	return FRONT_X - index * SPACING


func _update_stats() -> void:
	var rho: float = QueueModel.utilization(_config)
	_stats.text = "Colas M/M/1 · %s\nλ = %.1f llegan/min   μ = %.1f atiende/min   ρ = λ/μ = %.2f\nTeórico: Lq = %.1f en fila   Wq = %.1f min de espera\nAhora: delante de ti %d   detrás %d   llevas %.1f min%s" % [
		_config.display_name, _config.arrival_rate, _config.service_rate, rho,
		QueueModel.mean_queue_length(_config), QueueModel.mean_wait(_config),
		_ahead, _behind, _waited, "" if _done else "\n[%s] mantener: adelantar el tiempo" % Settings.key_name(InputActions.INTERACT)]
	_stats.reset_size()


func _person() -> AnimatedSprite2D:
	return _sprite(CROWD_FRAMES, CROWD_ANIMATIONS[_rng.index(CROWD_ANIMATIONS.size())], Vector2.ZERO, PERSON_HEIGHT)


func _sprite(frames: SpriteFrames, animation: StringName, feet: Vector2, height: float) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = animation
	var frame_height: float = frames.get_frame_texture(animation, 0).get_height()
	sprite.offset = Vector2(0.0, -frame_height / 2.0)
	sprite.scale = Vector2.ONE * (height / frame_height)
	sprite.position = feet
	sprite.play()
	return sprite


func _label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.88)
	style.border_color = QUEUE_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(5.0)
	label.add_theme_stylebox_override("normal", style)
	return label


func _draw_scene() -> void:
	var c: Control = _canvas
	if _is_bus:
		c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("9cc9e8"))  # Sky.
		for i: int in 8:  # City behind.
			var h: float = 60.0 + (i * 37 % 50)
			c.draw_rect(Rect2(i * 84.0, 196.0 - h, 76.0, h), [Color("c9824a"), Color("8fa7b8"), Color("d8b46a"), Color("b65f4f")][i % 4])
		c.draw_rect(Rect2(0.0, 196.0, SCREEN.x, 76.0), Color("b8b0a0"))  # Sidewalk.
		c.draw_rect(Rect2(0.0, 272.0, SCREEN.x, 8.0), Color("8a8478"))  # Curb.
		c.draw_rect(Rect2(0.0, 280.0, SCREEN.x, 80.0), Color("4a4c50"))  # Road.
		c.draw_rect(Rect2(120.0, 160.0, 300.0, 8.0), Color("3a5a7a"))  # Shelter roof.
		c.draw_rect(Rect2(124.0, 168.0, 6.0, 100.0), Color("3a5a7a"))
		c.draw_rect(Rect2(410.0, 168.0, 6.0, 100.0), Color("3a5a7a"))
		# The bus at the curb, door open: the server.
		c.draw_rect(Rect2(474.0, 176.0, 180.0, 100.0), Color("c0392b"))
		c.draw_rect(Rect2(474.0, 186.0, 180.0, 30.0), Color("9cc9e8"))
		c.draw_rect(Rect2(480.0, 222.0, 30.0, 54.0), Color("2c2c2c"))  # Door.
		c.draw_circle(Vector2(530.0, 278.0), 12.0, Color("1b1b1b"))
		c.draw_circle(Vector2(620.0, 278.0), 12.0, Color("1b1b1b"))
	else:
		c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("6f7f94"))  # Office wall.
		c.draw_rect(Rect2(0.0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), Color("3d4a5c"))
		c.draw_rect(Rect2(500.0, 150.0, 140.0, 118.0), Color("2c3e50"))  # The window: the server.
		c.draw_rect(Rect2(500.0, 222.0, 140.0, 14.0), Color("9a6b4f"))
		c.draw_string(c.get_theme_default_font(), Vector2(520.0, 172.0), _config.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)
		for x: float in range(0, 500, 40):
			c.draw_line(Vector2(x, FLOOR_Y + 30.0), Vector2(x + 20.0, FLOOR_Y + 30.0), Color(1.0, 0.85, 0.3, 0.5), 2.0)
	# "TÚ" over the player.
	var font: Font = c.get_theme_default_font()
	var head: Vector2 = _player.position + Vector2(0.0, -PERSON_HEIGHT - 6.0)
	c.draw_string(font, head + Vector2(-12.0, -6.0), "TÚ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)
	c.draw_colored_polygon(PackedVector2Array([head + Vector2(-5.0, 0.0), head + Vector2(5.0, 0.0), head + Vector2(0.0, 6.0)]), ACCENT)
	# People behind the player that do not fit.
	if _behind > 0:
		var shown: int = mini(_behind, MAX_VISIBLE_BEHIND)
		for i: int in shown:
			var x: float = _slot_x(_people.size() + i)
			if x > 8.0:
				c.draw_rect(Rect2(x - 7.0, FLOOR_Y - 40.0, 14.0, 40.0), Color(0.2, 0.2, 0.25, 0.75))
		c.draw_string(font, Vector2(8.0, FLOOR_Y + 22.0), "detrás de ti: %d" % _behind, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	_draw_service_bar(c, font)
	for note: Dictionary in _notes:
		var t: float = note.age / NOTE_SECONDS
		c.draw_string(font, note.position + Vector2(-30.0, -NOTE_RISE * t), note.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			13, Color(1.0, 1.0, 1.0, 1.0 - t))
	_draw_plot(c, font)


## Over the server: how much of the current service is done (the person at the front, or the player).
func _draw_service_bar(c: Control, font: Font) -> void:
	if _done or (_ahead == 0 and not _being_served):
		return
	var bar: Rect2 = Rect2(FRONT_X - 30.0, FLOOR_Y - 104.0, 60.0, 7.0)
	var progress: float = 1.0 - clampf(_service_left / maxf(_service_total, 0.001), 0.0, 1.0)
	c.draw_rect(bar.grow(1.0), Color(0.05, 0.08, 0.15, 0.9))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), QUEUE_COLOR)
	var who: String = "atendiéndote" if _being_served else "atendiendo"
	c.draw_string(font, bar.position + Vector2(0.0, -4.0), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


## N(t): people in the system over time, against the theoretical L = ρ / (1 - ρ).
func _draw_plot(c: Control, font: Font) -> void:
	var box: Rect2 = Rect2(438.0, 6.0, 196.0, 92.0)
	c.draw_rect(box, Color(0.05, 0.08, 0.15, 0.88))
	c.draw_rect(box, QUEUE_COLOR, false, 1.0)
	c.draw_string(font, box.position + Vector2(5.0, 13.0), "N(t): personas en el sistema", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	var plot: Rect2 = Rect2(box.position + Vector2(6.0, 20.0), box.size - Vector2(12.0, 26.0))
	var rho: float = QueueModel.utilization(_config)
	var l_theory: float = rho / (1.0 - rho)
	var top: float = maxf(l_theory * 2.0, 4.0)
	for value: int in _history:
		top = maxf(top, value + 1.0)
	var y_theory: float = plot.end.y - plot.size.y * l_theory / top
	c.draw_line(Vector2(plot.position.x, y_theory), Vector2(plot.end.x, y_theory), Color(1.0, 0.85, 0.3, 0.8), 1.0)
	c.draw_string(font, Vector2(plot.end.x - 58.0, y_theory - 2.0), "L = %.1f" % l_theory, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ACCENT)
	if _history.size() >= 2:
		var points: PackedVector2Array = []
		for i: int in _history.size():
			var x: float = plot.position.x + plot.size.x * i / float(HISTORY_SIZE - 1)
			points.append(Vector2(x, plot.end.y - plot.size.y * _history[i] / top))
		c.draw_polyline(points, QUEUE_COLOR, 2.0)
