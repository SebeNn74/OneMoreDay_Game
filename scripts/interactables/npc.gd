class_name Npc
extends Interactable
## A secondary character that offers a decision.
## It waits where it was placed until the player interacts, offers once, and is then used up.

const ACTION_FORMAT: String = "Hablar con %s"
const USED_TINT: Color = Color(0.5, 0.5, 0.5)

@export var decision: DecisionDefinition
@export var placeholder_color: Color = Color(0.9, 0.6, 0.2)

@onready var _body: StaticBody2D = $Body
@onready var _placeholder: ColorRect = $Placeholder


func _ready() -> void:
	super()
	assert(decision != null, "%s: decision is not assigned." % name)
	_body.collision_layer = PhysicsLayers.NPC
	_body.collision_mask = 0
	_placeholder.color = placeholder_color
	if action_text.is_empty():
		action_text = ACTION_FORMAT % decision.speaker_name


func _on_interact(_interactor: Node) -> void:
	Simulation.report(Simulation.MODEL_AGENTS, "%s ofrece %d opciones (una sola vez)" % [
		decision.speaker_name, decision.options.size()])
	EventBus.decision_requested.emit(decision)
	enabled = false
	_placeholder.modulate = USED_TINT
