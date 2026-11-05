extends Node
## Autoload. Runs the day: loads each step of the DaySequence in order,
## advances when a level is completed, and handles end screens and the main menu.

const DAY_SEQUENCE: DaySequence = preload("res://data/levels/day_sequence.tres")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/global/scene_transition.tscn")
const MAIN_MENU_SCENE: String = "res://scenes/global/main_menu.tscn"

## Outcome of the last finished day. Null until a day finishes.
var last_result: DayResult

var _steps: Array[DayStep] = []
var _current_index: int = -1  # -1 means no day is running.
var _is_changing_scene: bool = false
var _transition: SceneTransition
## A stat ran out while a scene transition was running. Applied when it ends.
var _pending_defeat_stat: StatDefinition

func _ready() -> void:
	_transition = TRANSITION_SCENE.instantiate()
	add_child(_transition)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.stat_depleted.connect(_on_stat_depleted)


## Starts a new day from the home scene with fresh stats.
func start_day() -> void:
	if _is_changing_scene:
		return
	last_result = null
	_pending_defeat_stat = null
	StatsManager.reset_all()
	_steps = DAY_SEQUENCE.build_steps()
	GameManager.change_state(GameState.Type.PLAYING)
	_go_to_step(0)


## Ends the day and shows the victory or defeat screen.
## [param depleted_stat] is the cause of a defeat (null if unknown or on victory).
func finish_day(victory: bool, depleted_stat: StatDefinition = null) -> void:
	if _is_changing_scene:
		return
	_current_index = -1
	_pending_defeat_stat = null
	last_result = DayResult.new(victory, depleted_stat)
	print("[SceneManager] Day finished. Victory: %s" % victory)
	GameManager.change_state(GameState.Type.VICTORY if victory else GameState.Type.GAME_OVER)
	EventBus.day_finished.emit(last_result)
	_change_scene(DAY_SEQUENCE.victory_scene if victory else DAY_SEQUENCE.defeat_scene)


## Abandons the current day and goes back to the main menu.
func return_to_menu() -> void:
	if _is_changing_scene:
		return
	_current_index = -1
	_pending_defeat_stat = null
	GameManager.change_state(GameState.Type.MENU)
	_change_scene(MAIN_MENU_SCENE)


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
		return

	# Last level done: victory only if every stat is still healthy.
	var depleted_stat: StatDefinition = StatsManager.get_depleted_stat()
	finish_day(depleted_stat == null, depleted_stat)


func _on_stat_depleted(type: StatDefinition.Type) -> void:
	if not is_day_active():
		return

	var definition: StatDefinition = StatsManager.get_definition(type)
	if _is_changing_scene:
		# finish_day() would be ignored mid-transition: remember it and apply it afterwards.
		if _pending_defeat_stat == null:
			_pending_defeat_stat = definition
		return
	finish_day(false, definition)


func _apply_pending_defeat() -> void:
	if _pending_defeat_stat != null and is_day_active():
		finish_day(false, _pending_defeat_stat)


func _go_to_step(index: int) -> void:
	_current_index = index
	var step: DayStep = _steps[index]
	print("[SceneManager] Step %d/%d: %s %d -> %s" % [
		index + 1, _steps.size(), DayStep.Stage.keys()[step.stage], step.number_in_stage, step.scene_path
	])
	await _change_scene(step.scene_path)
	EventBus.day_step_started.emit(step)
	_apply_pending_defeat()


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
