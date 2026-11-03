class_name DayStep
extends RefCounted
## One step of the day: which scene to load and where it sits in the day.

enum Stage { HOME, COMMUTE, WORK, RETURN }

var stage: Stage
var scene_path: String
## 1-based position inside its stage (commute_02 -> 2).
var number_in_stage: int


func _init(step_stage: Stage, step_scene_path: String, step_number: int) -> void:
	stage = step_stage
	scene_path = step_scene_path
	number_in_stage = step_number
