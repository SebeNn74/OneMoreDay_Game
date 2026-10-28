class_name Player
extends CharacterBody2D
## Top-down player controller. Reads input, moves, and wires its child components.

signal facing_changed(new_direction: Vector2)

@export var movement_config: MovementConfig

## Cardinal direction the player is facing. Read by the interaction detector.
var facing_direction: Vector2 = Vector2.DOWN

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var animator: PlayerAnimator = $Animator


func _ready() -> void:
	assert(movement_config != null, "Player: movement_config is not assigned.")
	state_machine.state_changed.connect(animator.on_state_changed)
	facing_changed.connect(animator.on_facing_changed)
	animator.one_shot_finished.connect(state_machine.finish_one_shot)


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = _read_input_direction()
	_update_facing_direction(input_direction)
	state_machine.update_locomotion(
		not input_direction.is_zero_approx(),
		Input.is_action_pressed(InputActions.RUN)
	)
	_move(input_direction)


# TEMPORARY: P1-06 will replace this with the interaction detector.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.INTERACT):
		state_machine.request_one_shot(PlayerState.Type.INTERACT)


func _read_input_direction() -> Vector2:
	return Input.get_vector(
		InputActions.MOVE_LEFT,
		InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP,
		InputActions.MOVE_DOWN
	)


func _move(direction: Vector2) -> void:
	velocity = direction * _get_current_speed()
	move_and_slide()


## The speed follows the state: IDLE and one-shot states have speed 0.
func _get_current_speed() -> float:
	match state_machine.current_state:
		PlayerState.Type.WALK:
			return movement_config.walk_speed
		PlayerState.Type.RUN:
			return movement_config.run_speed
	return 0.0


## Keeps the last facing direction when standing still or locked.
func _update_facing_direction(direction: Vector2) -> void:
	if direction.is_zero_approx() or state_machine.is_locked():
		return

	var new_facing: Vector2 = DirectionUtils.to_cardinal(direction)
	if new_facing == facing_direction:
		return

	facing_direction = new_facing
	facing_changed.emit(facing_direction)
