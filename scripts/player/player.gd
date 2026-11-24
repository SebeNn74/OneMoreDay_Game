class_name Player
extends CharacterBody2D
## Top-down player controller. Reads input, moves, and wires its child components.

signal facing_changed(new_direction: Vector2)

## Group the player joins, so other nodes (hostiles) can find it.
const GROUP: StringName = &"player"
const REST_TINT: Color = Color(0.7, 0.85, 1.0)
## A hit pushes the player away from the hostile at this speed (times its knockback_strength),
## slowing down at KNOCKBACK_DECAY px/s². The HURT state keeps the player still meanwhile.
const KNOCKBACK_SPEED: float = 240.0
const KNOCKBACK_DECAY: float = 1100.0
const HIT_FLASH_COLOR: Color = Color(1.0, 0.3, 0.3)
const HIT_FLASH_SECONDS: float = 0.35
const HIT_SHAKE_PIXELS: float = 3.0

@export var movement_config: MovementConfig

## Cardinal direction the player is facing.
var facing_direction: Vector2 = Vector2.DOWN
## Scales the movement speed. Written by PlayerSimulationBridge.
var speed_multiplier: float = 1.0
var is_resting: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _flash_tween: Tween

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var animator: PlayerAnimator = $Animator
@onready var interaction_detector: InteractionDetector = $InteractionDetector
@onready var interaction_prompt: InteractionPrompt = $InteractionPrompt
@onready var camera: PlayerCamera = $Camera
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	assert(movement_config != null, "Player: movement_config is not assigned.")
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.PLAYER_BLOCKERS
	state_machine.state_changed.connect(animator.on_state_changed)
	animator.one_shot_finished.connect(state_machine.finish_one_shot)
	facing_changed.connect(animator.on_facing_changed)
	facing_changed.connect(interaction_detector.face)
	interaction_detector.focus_changed.connect(interaction_prompt.on_focus_changed)
	hurtbox.hit_received.connect(_on_hit_received)
	interaction_detector.face(facing_direction)


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = _read_input_direction()
	if is_resting and not input_direction.is_zero_approx():
		stop_resting()
	_update_facing_direction(input_direction)
	state_machine.update_locomotion(
		not input_direction.is_zero_approx(),
		_is_run_requested()
	)
	_move(input_direction, delta)


func is_controllable() -> bool:
	return GameManager.current_state == GameState.Type.PLAYING and not SceneManager.is_transitioning()


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


func _move(direction: Vector2, delta: float) -> void:
	velocity = direction * _get_current_speed() + _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)


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


func _on_hit_received(source: Node) -> void:
	stop_resting()
	state_machine.request_one_shot(PlayerState.Type.HURT)
	var strength: float = 1.0
	var push: Vector2 = -facing_direction
	var source_2d: Node2D = source as Node2D
	if source_2d != null:
		var away: Vector2 = global_position - source_2d.global_position
		if not away.is_zero_approx():
			push = away.normalized()
		var hostile: Hostile = source as Hostile
		if hostile != null:
			strength = hostile.definition.knockback_strength
	_knockback = push * KNOCKBACK_SPEED * strength
	camera.shake(HIT_SHAKE_PIXELS * strength)
	if _flash_tween != null:
		_flash_tween.kill()
	animator.modulate = HIT_FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(animator, "modulate", Color.WHITE, HIT_FLASH_SECONDS)


func start_resting() -> void:
	is_resting = true
	animator.modulate = REST_TINT


func stop_resting() -> void:
	if not is_resting:
		return
	is_resting = false
	animator.modulate = Color.WHITE
