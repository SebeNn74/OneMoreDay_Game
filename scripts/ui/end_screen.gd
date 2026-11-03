class_name EndScreen
extends Control
## Placeholder victory/defeat screen.
## Interact restarts the day.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.INTERACT):
		SceneManager.start_day()
