class_name PhoneInteractable
extends Interactable
## The phone: shows a notification.

@export var event_stage: GameEvent.Stage = GameEvent.Stage.HOME

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()
	animated_sprite.play("phone")
	AudioManager.ring_phone(true)
	

func _on_interact(_interactor: Node) -> void:
	EventRunner.trigger(event_stage)
	AudioManager.ring_phone(false)
	animated_sprite.stop()
	animated_sprite.frame = 0
	enabled = false  # Used up: the prompt disappears.
