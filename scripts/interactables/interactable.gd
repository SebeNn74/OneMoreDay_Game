class_name Interactable
extends Area2D
## Base class for anything the player can interact with (bed, phone, NPC...).
## To add behavior, extend this class and override _on_interact().

## Emitted when the player interacts with this object.
signal interacted(interactor: Node)

@export var enabled: bool = true
## Action shown in the prompt (player-visible, Spanish). Example: "Revisar celular".
@export var action_text: String = ""
## Where the prompt appears, relative to this node.
@export var prompt_offset: Vector2 = Vector2(0.0, -32.0)


func _ready() -> void:
	# Set in code so a wrong Inspector value cannot break detection.
	collision_layer = PhysicsLayers.INTERACTABLES
	collision_mask = 0
	monitoring = false


func is_available() -> bool:
	return enabled


func interact(interactor: Node) -> void:
	if not is_available():
		return
	_on_interact(interactor)
	interacted.emit(interactor)
	EventBus.player_interacted.emit(self)


## Override in subclasses.
func _on_interact(_interactor: Node) -> void:
	pass
