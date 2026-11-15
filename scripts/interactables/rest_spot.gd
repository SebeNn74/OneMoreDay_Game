class_name RestSpot
extends Interactable
## A place to sit (chair, bench). Interacting makes the player rest: standing still, energy
## recovers while time keeps running (model 5, REST). Moving or getting hit stands the player up.
## Reusable: it does not get used up.

@export var placeholder_color: Color = Color(0.3, 0.55, 0.85)

@onready var _placeholder: ColorRect = $Placeholder


func _ready() -> void:
	super()
	_placeholder.color = placeholder_color


func _on_interact(interactor: Node) -> void:
	var player: Player = interactor as Player
	if player == null or player.is_resting:
		return
	player.start_resting()
	Simulation.report(Simulation.MODEL_DYNAMICS, "Descansando: la energía se recupera a costa de tiempo")
