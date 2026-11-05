class_name DayResult
extends RefCounted
## Outcome of a finished day.

var is_victory: bool
## The stat that ran out. Null on victory (or on a defeat with no specific cause).
var depleted_stat: StatDefinition


func _init(victory: bool, stat: StatDefinition = null) -> void:
	is_victory = victory
	depleted_stat = stat
