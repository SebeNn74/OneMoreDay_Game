class_name Stat
extends RefCounted
## Runtime value of a single stat.

var definition: StatDefinition
var value: float


func _init(stat_definition: StatDefinition) -> void:
	definition = stat_definition
	reset()


func reset() -> void:
	value = definition.initial_value


## Applies a change respecting the definition limits.
## Returns the change actually applied, which differs from [param amount] when clamped.
func modify(amount: float) -> float:
	var previous_value: float = value
	value = definition.clamp_value(value + amount)
	return value - previous_value


func is_depleted() -> bool:
	return definition.is_depleted_at(value)
