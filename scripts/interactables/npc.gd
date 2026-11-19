class_name Npc
extends Interactable
## A secondary character that offers a decision.
## It waits where it was placed until the player interacts, offers once, and is then used up.

const ACTION_FORMAT: String = "Hablar con %s"
const USED_TINT: Color = Color(0.5, 0.5, 0.5)

@export var decision: DecisionDefinition
@export var sprite_animation: StringName = &""

@onready var _body: StaticBody2D = $Body
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()
	assert(decision != null, "%s: decision is not assigned." % name)
	_body.collision_layer = PhysicsLayers.NPC
	_body.collision_mask = 0
	if not sprite_animation.is_empty():
		assert(
			_animated_sprite.sprite_frames != null
			and _animated_sprite.sprite_frames.has_animation(sprite_animation),
			"%s: animation '%s' is missing from npc_sprite_frames.tres." % [name, sprite_animation]
		)
		_animated_sprite.animation = sprite_animation
		_animated_sprite.play()
	else:
		_animated_sprite.hide()
	if action_text.is_empty():
		action_text = ACTION_FORMAT % decision.speaker_name


func _on_interact(_interactor: Node) -> void:
	Simulation.report(Simulation.MODEL_AGENTS, "%s ofrece %d opciones (una sola vez)" % [
		decision.speaker_name, decision.options.size()])
	EventBus.decision_requested.emit(decision)
	enabled = false
	_animated_sprite.modulate = USED_TINT
