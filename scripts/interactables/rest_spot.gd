class_name RestSpot
extends Interactable
## A place to sit (chair, bench). Interacting makes the player rest: standing still, energy
## recovers while time keeps running (model 5, REST). Moving or getting hit stands the player up.
## Reusable: it does not get used up.

@export_group("Visual")
@export var texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite
@onready var _footprint_shape: CollisionShape2D = $Footprint


func _ready() -> void:
	super()
	if _sprite == null:
		return
	if texture == null:
		_sprite.texture = null
		_footprint_shape.shape = null
		return
	var texture_size: Vector2 = texture.get_size()
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.offset = Vector2(-texture_size.x / 2.0, -texture_size.y)  # Origin at the bottom center.


func _on_interact(interactor: Node) -> void:
	var player: Player = interactor as Player
	if player == null or player.is_resting:
		return
	player.start_resting()
	Simulation.report(Simulation.MODEL_DYNAMICS, "Descansando: la energía se recupera a costa de tiempo")
