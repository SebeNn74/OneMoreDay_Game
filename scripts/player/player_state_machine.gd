class_name PlayerStateMachine
extends Node
## Holds the player's current state and validates transitions.
## Locomotion states (IDLE/WALK/RUN) follow the input.
## One-shot states (INTERACT/HURT/FALL) lock the player until finish_one_shot().

signal state_changed(new_state: PlayerState.Type, previous_state: PlayerState.Type)

var current_state: PlayerState.Type = PlayerState.Type.IDLE


func is_locked() -> bool:
	return PlayerState.is_one_shot(current_state)


## Updates IDLE/WALK/RUN from input. Ignored while a one-shot state is active.
func update_locomotion(is_moving: bool, is_running: bool) -> void:
	if is_locked():
		return

	var target_state: PlayerState.Type = PlayerState.Type.IDLE
	if is_moving:
		target_state = PlayerState.Type.RUN if is_running else PlayerState.Type.WALK
	_set_state(target_state)


## Starts a one-shot state. Returns false if another one-shot is still active.
func request_one_shot(state: PlayerState.Type) -> bool:
	assert(PlayerState.is_one_shot(state), "Not a one-shot state: %s" % state)
	if is_locked():
		return false
	_set_state(state)
	return true


## Called when the one-shot animation ends. Goes back to IDLE.
func finish_one_shot() -> void:
	if is_locked():
		_set_state(PlayerState.Type.IDLE)


func _set_state(new_state: PlayerState.Type) -> void:
	if new_state == current_state:
		return

	var previous_state: PlayerState.Type = current_state
	current_state = new_state
	state_changed.emit(new_state, previous_state)
