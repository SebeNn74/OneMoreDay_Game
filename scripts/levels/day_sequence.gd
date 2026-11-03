class_name DaySequence
extends Resource
## Ordered scenes of one day. Edit the .tres file to reorder or add levels.

@export_file("*.tscn") var home_scene: String
@export_file("*.tscn") var commute_scenes: Array[String] = []
@export_file("*.tscn") var work_scenes: Array[String] = []
@export_file("*.tscn") var return_scenes: Array[String] = []
@export_file("*.tscn") var victory_scene: String
@export_file("*.tscn") var defeat_scene: String


## Flattens the playable stages into one ordered list.
func build_steps() -> Array[DayStep]:
	var steps: Array[DayStep] = []
	steps.append(_make_step(DayStep.Stage.HOME, home_scene, 1))
	_append_stage(steps, DayStep.Stage.COMMUTE, commute_scenes)
	_append_stage(steps, DayStep.Stage.WORK, work_scenes)
	_append_stage(steps, DayStep.Stage.RETURN, return_scenes)
	return steps


func _append_stage(steps: Array[DayStep], stage: DayStep.Stage, paths: Array[String]) -> void:
	for index: int in paths.size():
		steps.append(_make_step(stage, paths[index], index + 1))


func _make_step(stage: DayStep.Stage, path: String, number: int) -> DayStep:
	assert(ResourceLoader.exists(path), "DaySequence: scene not found: '%s'" % path)
	return DayStep.new(stage, path, number)
