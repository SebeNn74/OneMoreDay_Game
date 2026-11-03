extends BaseLevel
## TEMPORARY test level.


func _ready() -> void:
	super()
	EventBus.level_completed.connect(func() -> void: print("Level completed"))
