extends Node
## Autoload. Holds the global game state and applies its side effects.

signal state_changed(new_state: GameState.Type, previous_state: GameState.Type)

var current_state: GameState.Type = GameState.Type.MENU


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must keep reading input while paused.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE):
		toggle_pause()


## PLAYING <-> PAUSED. Ignored in any other state.
func toggle_pause() -> void:
	match current_state:
		GameState.Type.PLAYING:
			change_state(GameState.Type.PAUSED)
		GameState.Type.PAUSED:
			change_state(GameState.Type.PLAYING)


func change_state(new_state: GameState.Type) -> void:
	if new_state == current_state:
		return

	var previous_state: GameState.Type = current_state
	current_state = new_state
	get_tree().paused = (new_state == GameState.Type.PAUSED)
	print("[GameManager] %s -> %s" % [
		GameState.Type.keys()[previous_state], GameState.Type.keys()[new_state]
	])
	state_changed.emit(new_state, previous_state)
