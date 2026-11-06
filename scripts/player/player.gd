class_name Player
extends CharacterBody2D
## Top-down player controller. Reads input, moves, and wires its child components.

signal facing_changed(new_direction: Vector2)

@export var movement_config: MovementConfig

## Cardinal direction the player is facing.
var facing_direction: Vector2 = Vector2.DOWN
## Scales the movement speed. Written by PlayerSimulationBridge.
var speed_multiplier: float = 1.0

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var animator: PlayerAnimator = $Animator
@onready var interaction_detector: InteractionDetector = $InteractionDetector
@onready var interaction_prompt: InteractionPrompt = $InteractionPrompt


func _ready() -> void:
	assert(movement_config != null, "Player: movement_config is not assigned.")
	state_machine.state_changed.connect(animator.on_state_changed)
	animator.one_shot_finished.connect(state_machine.finish_one_shot)
	facing_changed.connect(animator.on_facing_changed)
	facing_changed.connect(interaction_detector.face)
	interaction_detector.focus_changed.connect(interaction_prompt.on_focus_changed)
	interaction_detector.face(facing_direction)


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = _read_input_direction()
	_update_facing_direction(input_direction)
	state_machine.update_locomotion(
		not input_direction.is_zero_approx(),
		_is_run_requested()
	)
	_move(input_direction)


func is_controllable() -> bool:
	return not SceneManager.is_transitioning()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.INTERACT):
		_try_interact()


func _try_interact() -> void:
	if not is_controllable() or state_machine.is_locked():
		return
	if interaction_detector.interact(self):
		state_machine.request_one_shot(PlayerState.Type.INTERACT)


func _read_input_direction() -> Vector2:
	if not is_controllable():
		return Vector2.ZERO
	return Input.get_vector(
		InputActions.MOVE_LEFT,
		InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP,
		InputActions.MOVE_DOWN
	)


func _is_run_requested() -> bool:
	return is_controllable() and Input.is_action_pressed(InputActions.RUN)


func _move(direction: Vector2) -> void:
	velocity = direction * _get_current_speed()
	move_and_slide()


## The speed follows the state: IDLE and one-shot states have speed 0.
func _get_current_speed() -> float:
	match state_machine.current_state:
		PlayerState.Type.WALK:
			return movement_config.walk_speed * speed_multiplier
		PlayerState.Type.RUN:
			return movement_config.run_speed * speed_multiplier
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
