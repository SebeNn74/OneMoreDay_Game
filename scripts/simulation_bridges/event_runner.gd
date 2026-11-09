class_name EventRunner
extends RefCounted
## Runs one random event: draws it, shows its text and applies its effects.


## Returns the event that ran, or null if the stage has no events left today.
static func trigger(stage: GameEvent.Stage) -> GameEvent:
	var event: GameEvent = Simulation.draw_event(stage)
	if event == null:
		return null
	EventBus.notification_requested.emit(event.text)
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
