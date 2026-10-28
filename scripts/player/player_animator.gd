class_name PlayerAnimator
extends AnimatedSprite2D
## Plays the animation matching the player's state and facing direction.
## Knows nothing about Player or the state machine: it only receives updates.

## Emitted when a one-shot animation (interact, hurt, fall) ends.
signal one_shot_finished

var _state: PlayerState.Type = PlayerState.Type.IDLE
var _facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	assert(sprite_frames != null, "PlayerAnimator: sprite_frames is not assigned.")
	animation_finished.connect(_on_animation_finished)
	_play_current()


func on_state_changed(new_state: PlayerState.Type, _previous_state: PlayerState.Type) -> void:
	_state = new_state
	_play_current()


func on_facing_changed(new_direction: Vector2) -> void:
	_facing = new_direction
	_play_current()


func _play_current() -> void:
	play(_resolve_animation_name())


## "<state>_<direction>" if it exists (walk_left), otherwise "<state>" (hurt).
func _resolve_animation_name() -> StringName:
	var base_name: StringName = PlayerState.animation_base_name(_state)
	var directional_name: StringName = StringName("%s_%s" % [base_name, DirectionUtils.name_of(_facing)])
	var animation_name: StringName = directional_name if sprite_frames.has_animation(directional_name) else base_name
	assert(sprite_frames.has_animation(animation_name), "Missing animation: %s" % animation_name)
	return animation_name


func _on_animation_finished() -> void:
	if PlayerState.is_one_shot(_state):
		one_shot_finished.emit()
