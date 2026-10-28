class_name PlayerState
extends RefCounted
## Player states and helpers. Pure data, no behavior.

enum Type { IDLE, WALK, RUN, INTERACT, HURT, FALL }


## One-shot states play their animation once and lock the player until it ends.
static func is_one_shot(type: Type) -> bool:
	return type in [Type.INTERACT, Type.HURT, Type.FALL]


## Base animation name, derived from the enum key (RUN -> &"run").
## Must match the animation names generated in the SpriteFrames.
static func animation_base_name(type: Type) -> StringName:
	return StringName(Type.keys()[type].to_lower())
