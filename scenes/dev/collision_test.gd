extends Node2D
## TEMPORARY test scene for collisions and interaction.


func _ready() -> void:
	EventBus.player_interacted.connect(
		func(target: Node) -> void: print("Interacted with: ", target.name)
	)
