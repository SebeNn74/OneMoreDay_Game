class_name ItemPickup
extends Interactable
## An object lying in the level. Interact to use it; it applies its effect once and disappears.
## An item that costs money cannot be taken if the player cannot afford it.

const NOT_ENOUGH_MONEY_TEXT: String = "No te alcanza el dinero."

@export var item: ItemDefinition

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()
	assert(item != null, "%s: item is not assigned." % name)
	assert(
		_animated_sprite.sprite_frames != null
		and _animated_sprite.sprite_frames.has_animation(item.sprite_animation),
		"%s: animation '%s' is missing from the item SpriteFrames." % [name, item.sprite_animation]
	)
	_animated_sprite.animation = item.sprite_animation
	_animated_sprite.play()
	if action_text.is_empty():
		action_text = item.action_text


func _on_interact(_interactor: Node) -> void:
	if not StatsManager.can_afford(StatDefinition.Type.MONEY, item.money):
		EventBus.notification_requested.emit(NOT_ENOUGH_MONEY_TEXT)
		return
	Simulation.apply_change(item.money, item.energy, item.time)
	EventBus.item_used.emit(item)
	enabled = false
	hide()
