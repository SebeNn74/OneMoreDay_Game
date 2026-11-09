class_name EventZone
extends Area2D
## Runs one random event the first time the player enters it.
## One zone = one event: place as many as the level should have.

## Stage used when the level runs alone (F6), where there is no current day step.
@export var stage_when_testing: GameEvent.Stage = GameEvent.Stage.COMMUTE


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player) or GameManager.current_state != GameState.Type.PLAYING:
		return
	set_deferred("monitoring", false)  # Fires only once.
	EventRunner.trigger(EventRunner.current_stage(stage_when_testing))
