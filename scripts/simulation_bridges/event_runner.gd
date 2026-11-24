class_name EventRunner
extends RefCounted
## Runs one random event: draws one that fits where the player is (BaseLevel.place), shows it as a
## phone toast that does not stop the game, and applies its effects.


## Returns the event that ran, or null if no event fits today.
static func trigger(stage: GameEvent.Stage) -> GameEvent:
	var level: BaseLevel = (Engine.get_main_loop() as SceneTree).current_scene as BaseLevel
	var event: GameEvent = Simulation.draw_event(stage, level.place if level != null else "")
	if event == null:
		return null
	EventBus.toast_requested.emit(event.text)
	Simulation.apply_event(event)
	EventBus.game_event_triggered.emit(event)
	return event


## Event stage matching the day step being played.
## [param fallback] is used when no day is running.
static func current_stage(fallback: GameEvent.Stage) -> GameEvent.Stage:
	var step: DayStep = SceneManager.get_current_step()
	if step == null:
		return fallback
	match step.stage:
		DayStep.Stage.HOME:
			return GameEvent.Stage.HOME
		DayStep.Stage.COMMUTE:
			return GameEvent.Stage.COMMUTE
		DayStep.Stage.WORK:
			return GameEvent.Stage.WORK
		DayStep.Stage.RETURN:
			return GameEvent.Stage.RETURN
	return fallback
