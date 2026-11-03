@tool
extends EditorScript
## Creates the level scenes as inherited scenes of base_level.tscn.
## Skips files that already exist, so painted levels are never overwritten.
## Run: open this file in the Script editor, then File > Run (Ctrl+Shift+X).
##
## If it fails, create each one manually: Scene > New Inherited Scene.

const BASE_LEVEL_PATH: String = "res://scenes/base_level.tscn"

const LEVEL_PATHS: Array[String] = [
	"res://scenes/home/home_01.tscn",
	"res://scenes/commute/commute_01.tscn",
	"res://scenes/commute/commute_02.tscn",
	"res://scenes/commute/commute_03.tscn",
	"res://scenes/work/work_01.tscn",
	"res://scenes/work/work_02.tscn",
	"res://scenes/work/work_03.tscn",
	"res://scenes/return/return_01.tscn",
	"res://scenes/return/return_02.tscn",
	"res://scenes/return/return_03.tscn",
]


func _run() -> void:
	var base_scene: PackedScene = load(BASE_LEVEL_PATH)
	if base_scene == null:
		push_error("Base level not found: %s" % BASE_LEVEL_PATH)
		return

	var created: int = 0
	for path: String in LEVEL_PATHS:
		if ResourceLoader.exists(path):
			print("Skipped (already exists): %s" % path)
			continue
		if _create_level(base_scene, path):
			created += 1

	EditorInterface.get_resource_filesystem().scan()
	print("Done. %d level scene(s) created." % created)


func _create_level(base_scene: PackedScene, path: String) -> bool:
	var root: Node = base_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	root.name = path.get_file().get_basename().to_pascal_case()  # commute_01 -> Commute01

	var level_scene: PackedScene = PackedScene.new()
	var pack_error: Error = level_scene.pack(root)
	root.free()
	if pack_error != OK:
		push_error("Could not pack %s (error %d)." % [path, pack_error])
		return false

	var save_error: Error = ResourceSaver.save(level_scene, path)
	if save_error != OK:
		push_error("Could not save %s (error %d)." % [path, save_error])
		return false

	print("Created: %s" % path)
	return true
