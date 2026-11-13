class_name PhoneInteractable
extends Interactable
## The phone: shows a notification.

@export var event_stage: GameEvent.Stage = GameEvent.Stage.HOME

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()
	animated_sprite.play("phone")
	

func _on_interact(_interactor: Node) -> void:
	EventRunner.trigger(event_stage)
	animated_sprite.stop()
	animated_sprite.frame = 0
	enabled = false  # Used up: the prompt disappears.
