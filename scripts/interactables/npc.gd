class_name Npc
extends Interactable
## A secondary character that offers a decision.
## It waits where it was placed until the player interacts, offers once, and is then used up.

const ACTION_FORMAT: String = "Hablar con %s"
const USED_TINT: Color = Color(0.5, 0.5, 0.5)
## Circle under the feet while the NPC can be talked to: yellow, or purple for the special characters.
const MARKER_COLOR: Color = Color(1.0, 0.85, 0.2)
const SPECIAL_MARKER_COLOR: Color = Color(0.72, 0.38, 1.0)
const MARKER_RADIUS: float = 15.0
const MARKER_FLATTEN: float = 0.4
const MARKER_PULSE_SECONDS: float = 0.9

@export var decision: DecisionDefinition
@export var sprite_animation: StringName = &""
## Special characters (Abelardo, the boss of the letter) get a purple circle instead of a yellow one.
@export var is_special: bool = false

var _marker: Node2D

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
	_marker = Node2D.new()
	_marker.show_behind_parent = true  # Under the sprite.
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	var pulse: Tween = _marker.create_tween().set_loops()
	pulse.tween_property(_marker, "modulate:a", 0.45, MARKER_PULSE_SECONDS).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_marker, "modulate:a", 1.0, MARKER_PULSE_SECONDS).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	_marker.visible = enabled  # Gone once used, or while a level keeps it closed.


func _draw_marker() -> void:
	var color: Color = SPECIAL_MARKER_COLOR if is_special else MARKER_COLOR
	_marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, MARKER_FLATTEN))
	_marker.draw_circle(Vector2.ZERO, MARKER_RADIUS, Color(color, 0.45))
	_marker.draw_arc(Vector2.ZERO, MARKER_RADIUS, 0.0, TAU, 32, color, 2.0)


func _on_interact(_interactor: Node) -> void:
	Simulation.report(Simulation.MODEL_AGENTS, "%s ofrece %d opciones (una sola vez)" % [
		decision.speaker_name, decision.options.size()])
	EventBus.decision_requested.emit(decision)
	enabled = false
	_animated_sprite.modulate = USED_TINT
