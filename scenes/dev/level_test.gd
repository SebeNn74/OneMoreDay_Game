extends BaseLevel
## TEMPORARY test level.

const BUS_STOP_QUEUE: QueueConfig = preload("res://data/simulation/queue_bus_stop.tres")


func _ready() -> void:
	super()
	EventBus.level_completed.connect(func() -> void: print("Level completed"))


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_V:
			SceneManager.finish_day(true)
		KEY_K:
			SceneManager.finish_day(false)
		KEY_Q:
			Simulation.queue_wait(BUS_STOP_QUEUE)
		KEY_M:
			EventRunner.trigger(GameEvent.Stage.COMMUTE)
