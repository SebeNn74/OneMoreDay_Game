class_name Minigame
extends CanvasLayer
## A short travel minigame drawn over the level (bus ride, taxi ride). The game stays in DIALOG
## while it runs, so hostiles and resource flows stop.
## Flow: intro (title + how to play) -> 3, 2, 1 -> play for duration_seconds -> result -> finished.
## Subclasses draw in _build(stage), update in _play(delta) and say what it cost in _result().
## Each one implements a simulation model (model_name); a box shows it live (_model_text()).

signal finished

const DRAW_LAYER: int = 30  # Above every level UI, below pause (90) and transitions (100).
const COUNTDOWN_SECONDS: float = 3.0
const SCREEN: Vector2 = Vector2(640.0, 360.0)
const ACCENT: Color = Color(1.0, 0.85, 0.3)
const START_HINT: String = "[{interact}] Empezar"
const CONTINUE_HINT: String = "[{interact}] Seguir"
const TIME_FORMAT: String = "%s - %.0f s"
const SMALL_FONT: int = 12

@export var title: String = ""
@export_multiline var instructions: String = ""
@export_range(3.0, 60.0, 1.0, "suffix:s") var duration_seconds: float = 12.0
## Simulation model this minigame runs (shown in the intro and in the live box).
@export var model_name: String = ""

enum Phase { INTRO, COUNTDOWN, PLAY, RESULT }

var _phase: Phase = Phase.INTRO
var _phase_time: float = 0.0
var _time_left: float = 0.0
## What the result costs, set by _show_result(): {money, energy, time, summary}.
var _cost: Dictionary = {}
var _stage: Control
var _top_label: Label
var _panel: PanelContainer
var _panel_holder: CenterContainer
var _panel_box: VBoxContainer
var _big_label: Label
var _model_box: Label


func _ready() -> void:
	layer = DRAW_LAYER
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)
	AudioManager.play_temporary_music(&"minigame")
	_stage = Control.new()
	_stage.size = SCREEN
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	add_child(_stage)
	_build(_stage)

	_top_label = _make_label("", ACCENT, 0, HORIZONTAL_ALIGNMENT_CENTER)
	_top_label.size = Vector2(SCREEN.x, 20.0)
	_top_label.position = Vector2(0.0, 4.0)
	_top_label.add_theme_constant_override("outline_size", 4)
	_top_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_top_label)

	_big_label = _make_label("", Color.WHITE, 48, HORIZONTAL_ALIGNMENT_CENTER)
	_big_label.size = Vector2(SCREEN.x, 80.0)
	_big_label.position = Vector2(0.0, SCREEN.y / 2.0 - 60.0)
	_big_label.add_theme_constant_override("outline_size", 6)
	_big_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_big_label)

	_model_box = _make_label("", Color.WHITE, SMALL_FONT)
	_model_box.autowrap_mode = TextServer.AUTOWRAP_OFF
	_model_box.position = Vector2(6.0, 24.0)
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color(0.05, 0.08, 0.15, 0.82)
	box_style.border_color = ACCENT
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(3)
	box_style.set_content_margin_all(4.0)
	_model_box.add_theme_stylebox_override("normal", box_style)
	_model_box.visible = false
	add_child(_model_box)

	_show_panel([
		_make_label(title, ACCENT, 0, HORIZONTAL_ALIGNMENT_CENTER),
		_make_label("Modelo: " + model_name, Color(0.6, 0.85, 1.0), SMALL_FONT, HORIZONTAL_ALIGNMENT_CENTER),
		_make_label(Settings.with_keys(instructions), Color.WHITE, SMALL_FONT),
		_make_label(Settings.with_keys(START_HINT), ACCENT, SMALL_FONT, HORIZONTAL_ALIGNMENT_RIGHT),
	])


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputActions.INTERACT) or _phase == Phase.PLAY:
		_on_input(event)
		return
	get_viewport().set_input_as_handled()
	match _phase:
		Phase.INTRO:
			_hide_panel()
			_set_phase(Phase.COUNTDOWN)
		Phase.RESULT:
			_finish()


func _process(delta: float) -> void:
	_phase_time += delta
	match _phase:
		Phase.COUNTDOWN:
			var left: int = ceili(COUNTDOWN_SECONDS - _phase_time)
			var text: String = str(left) if left > 0 else "¡Ya!"
			if text != _big_label.text:
				AudioManager.play_sfx(&"countdown" if left > 0 else &"go")
			_big_label.text = text
			if _phase_time >= COUNTDOWN_SECONDS:
				_time_left = duration_seconds
				_set_phase(Phase.PLAY)
		Phase.PLAY:
			if _phase_time > 0.6:
				_big_label.text = ""
			_time_left -= delta
			_top_label.text = TIME_FORMAT % [title, maxf(_time_left, 0.0)]
			_play(delta)
			var model_text: String = _model_text()
			_model_box.visible = not model_text.is_empty()
			_model_box.text = "Modelo: %s
%s" % [model_name, model_text]
			_model_box.reset_size()
			if _time_left <= 0.0:
				AudioManager.play_sfx(&"go")
				_show_result()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0


func _show_result() -> void:
	_set_phase(Phase.RESULT)
	_big_label.text = ""
	_cost = _result()
	var effects: String = StatFormatter.describe_changes(_cost.money, _cost.energy, _cost.time)
	_show_panel([
		_make_label(title, ACCENT, 0, HORIZONTAL_ALIGNMENT_CENTER),
		_make_label(_cost.summary, Color.WHITE, 0, HORIZONTAL_ALIGNMENT_CENTER),
		_make_label(effects if not effects.is_empty() else "Sin costo extra", Color(1.0, 0.6, 0.55) if not effects.is_empty() else Color(0.6, 0.95, 0.6), SMALL_FONT, HORIZONTAL_ALIGNMENT_CENTER),
		_make_label(Settings.with_keys(CONTINUE_HINT), ACCENT, SMALL_FONT, HORIZONTAL_ALIGNMENT_RIGHT),
	])


func _finish() -> void:
	AudioManager.resume_stage_music()
	if GameManager.current_state == GameState.Type.DIALOG:
		GameManager.change_state(GameState.Type.PLAYING)
	# After leaving DIALOG, so a depleted stat ends the day right away.
	Simulation.apply_change(_cost.money, _cost.energy, _cost.time)
	finished.emit()
	queue_free()


func _show_panel(rows: Array) -> void:
	_hide_panel()
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size.x = 380.0
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 6)
	_panel.add_child(_panel_box)
	for row: Control in rows:
		_panel_box.add_child(row)
	# A container lays out the autowrapped labels (alone they measure at width 0: one letter per line).
	_panel_holder = CenterContainer.new()
	_panel_holder.size = SCREEN
	_panel_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_holder.add_child(_panel)
	add_child(_panel_holder)


func _hide_panel() -> void:
	if is_instance_valid(_panel_holder):
		_panel_holder.queue_free()
	_panel = null
	_panel_holder = null


func _make_label(text: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Ends the play phase now (a minigame whose rounds are all done).
func end_early() -> void:
	if _phase == Phase.PLAY:
		_time_left = 0.0


## Sprite with its origin at the feet and [param height] pixels tall.
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


## True while the player is actually playing (not reading or counting down).
func is_playing() -> bool:
	return _phase == Phase.PLAY


## Override: build the scene inside [param stage] (640x360).
func _build(_stage_control: Control) -> void:
	pass


## Override: one frame of play.
func _play(_delta: float) -> void:
	pass


## Override: live lines of the model box (empty = no box).
func _model_text() -> String:
	return ""


## Override: other input while playing (e.g. a lane change on a key press).
func _on_input(_event: InputEvent) -> void:
	pass


## Override: {money, energy, time, summary} once the time is up.
func _result() -> Dictionary:
	return {"money": 0.0, "energy": 0.0, "time": 0.0, "summary": ""}
