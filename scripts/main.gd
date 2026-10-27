extends Node2D


func _ready() -> void:
	EventBus.stat_changed.connect(_on_stat_changed)
	EventBus.stat_depleted.connect(_on_stat_depleted)

	StatsManager.modify(StatDefinition.Type.MONEY, -2500)
	StatsManager.modify(StatDefinition.Type.ENERGY, 20)   # Already at max: no signal.
	StatsManager.modify(StatDefinition.Type.ENERGY, -30)
	StatsManager.modify(StatDefinition.Type.ENERGY, -100) # Clamped at 0: depleted.
	GameManager.change_state(GameManager.State.PLAYING)


func _on_stat_changed(type: StatDefinition.Type, new_value: float, change: float) -> void:
	print("Stat %s -> %s (change: %s)" % [StatDefinition.Type.keys()[type], new_value, change])


func _on_stat_depleted(type: StatDefinition.Type) -> void:
	print("Stat %s depleted" % StatDefinition.Type.keys()[type])
