class_name DayResult
extends RefCounted
## Outcome of a finished day.

var is_victory: bool
## The stat that ran out. Null on victory (or on a defeat with no specific cause).
var depleted_stat: StatDefinition
## Text of the ending explaining why.
var reason: String


func _init(victory: bool, stat: StatDefinition = null, custom_reason: String = "") -> void:
	is_victory = victory
	depleted_stat = stat
	reason = custom_reason
	if reason.is_empty() and stat != null:
		reason = stat.depletion_message
