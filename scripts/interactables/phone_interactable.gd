class_name PhoneInteractable
extends Interactable
## The phone: shows a notification.

@export var event_stage: GameEvent.Stage = GameEvent.Stage.HOME


func _on_interact(_interactor: Node) -> void:
	EventRunner.trigger(event_stage)
	enabled = false  # Used up: the prompt disappears.
