class_name ItemPickup
extends Interactable
## An object lying in the level. Interact to use it; it applies its effect once and disappears.
## An item that costs money cannot be taken if the player cannot afford it.

const NOT_ENOUGH_MONEY_TEXT: String = "No te alcanza el dinero."

@export var item: ItemDefinition

@onready var _placeholder: ColorRect = $Placeholder


func _ready() -> void:
	super()
	assert(item != null, "%s: item is not assigned." % name)
	_placeholder.color = item.placeholder_color
	_placeholder.size = item.placeholder_size
	_placeholder.position = Vector2(-item.placeholder_size.x / 2.0, -item.placeholder_size.y)
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
