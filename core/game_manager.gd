extends Node
## Autoload. Holds the global game state (menu, playing, paused...)..).

enum State { MENU, PLAYING, PAUSED, GAMEOVER, VICTORY }

signal state_changed(new_state: State, previous_state: State)

var current_state: State = State.MENU


func change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	var previous_state: State = current_state
	current_state = new_state
	print("[GameManager] %s -> %s" % [State.keys()[previous_state], State.keys()[new_state]])
	state_changed.emit(new_state, previous_state)
