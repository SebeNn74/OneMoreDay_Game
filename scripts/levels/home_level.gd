class_name HomeLevel
extends BaseLevel
## The home: the exit stays locked until the player checks the phone.

## Message shown when the player touches the locked exit.
@export_multiline var blocked_exit_hint: String = ""

@onready var _phone: PhoneInteractable = %Phone


func _ready() -> void:
	super()
	_exit_zone.locked = true
	_exit_zone.blocked_entered.connect(_on_exit_blocked)
	_phone.interacted.connect(_on_phone_checked)


func _on_phone_checked(_interactor: Node) -> void:
	_exit_zone.locked = false


func _on_exit_blocked() -> void:
	if not blocked_exit_hint.is_empty():
		EventBus.notification_requested.emit(blocked_exit_hint)
