extends Node
## Autoload. Runs the day: loads each step of the DaySequence in order,
## advances when a level is completed, and handles victory/defeat screens.

const DAY_SEQUENCE: DaySequence = preload("res://data/levels/day_sequence.tres")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/global/scene_transition.tscn")

var _steps: Array[DayStep] = []
var _current_index: int = -1  # -1 means no day is running.
var _is_changing_scene: bool = false
var _transition: SceneTransition


func _ready() -> void:
	_transition = TRANSITION_SCENE.instantiate()
	add_child(_transition)
	EventBus.level_completed.connect(_on_level_completed)


## Starts a new day from the home scene with fresh stats.
func start_day() -> void:
	if _is_changing_scene:
		return
	StatsManager.reset_all()
	_steps = DAY_SEQUENCE.build_steps()
	GameManager.change_state(GameManager.State.PLAYING)
	_go_to_step(0)


## Ends the day and shows the victory or defeat screen.
func finish_day(victory: bool) -> void:
	if _is_changing_scene:
		return
	_current_index = -1
	GameManager.change_state(GameManager.State.VICTORY if victory else GameManager.State.GAME_OVER)
	_change_scene(DAY_SEQUENCE.victory_scene if victory else DAY_SEQUENCE.defeat_scene)


func is_day_active() -> bool:
	return _current_index >= 0


## Returns the step being played, or null if no day is running.
func get_current_step() -> DayStep:
	if not is_day_active():
		return null
	return _steps[_current_index]


func _on_level_completed() -> void:
	# Ignored when testing a level on its own (F6) or while a transition runs.
	if not is_day_active() or _is_changing_scene:
		return

	if _current_index + 1 < _steps.size():
		_go_to_step(_current_index + 1)
	else:
		finish_day(true)


func _go_to_step(index: int) -> void:
	_current_index = index
	var step: DayStep = _steps[index]
	print("[SceneManager] Step %d/%d: %s %d -> %s" % [
		index + 1, _steps.size(), DayStep.Stage.keys()[step.stage], step.number_in_stage, step.scene_path
	])
	await _change_scene(step.scene_path)
	EventBus.day_step_started.emit(step)


func _change_scene(path: String) -> void:
	_is_changing_scene = true
	await _transition.fade_out()

	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneManager: could not load '%s' (error %d)." % [path, error])
	else:
		# The swap happens at the end of the frame: wait for it before fading in.
		await get_tree().process_frame
		await get_tree().process_frame

	await _transition.fade_in()
	_is_changing_scene = false
