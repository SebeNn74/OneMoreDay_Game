extends SceneTree
## Checks the achievement rules. Uses its own save file, so the player's achievements are not touched.
## Run: godot --headless --path . -s res://tools/achievements_self_test.gd

var _failed: int = 0


func _initialize() -> void:
	await process_frame  # Autoloads are ready.
	var achievements: Node = root.get_node("Achievements")
	achievements.save_path = "user://achievements_self_test.cfg"
	achievements.reset()

	var day: RunSummary = RunSummary.new()
	day.is_victory = true
	day.hostile_hits = 2
	day.risks_taken = 3
	day.risks_lost = 1
	achievements.on_day_ended("V-01", day)
	_check("ending unlocks its achievement", achievements.is_unlocked("ending_V-01"))
	_check("hits: no Intocable", not achievements.is_unlocked("untouchable"))
	_check("2 risks won: no Apostador", not achievements.is_unlocked("gambler"))

	day.hostile_hits = 0
	day.risks_lost = 0
	achievements.on_day_ended("V-06", day)
	_check("no hits and a victory: Intocable", achievements.is_unlocked("untouchable"))
	_check("3 risks won: Apostador", achievements.is_unlocked("gambler"))
	_check("not every ending yet: no Coleccionista", not achievements.is_unlocked("collector"))

	day.is_victory = false
	day.hostile_hits = 0
	for id: String in ["V-02", "V-03", "V-04", "V-05", "D-01", "D-02", "D-03", "D-04", "D-05"]:
		achievements.on_day_ended(id, day)
	_check("a defeat without hits is not Intocable-worthy (already had it)", achievements.is_unlocked("untouchable"))
	_check("every ending: Coleccionista", achievements.is_unlocked("collector"))
	_check("count is all of them", achievements.unlocked_count() == achievements.DEFINITIONS.size())

	var reloaded: ConfigFile = ConfigFile.new()
	_check("saved to its own file", reloaded.load(achievements.save_path) == OK
		and reloaded.has_section_key("unlocked", "ending_V-06"))
	achievements.reset()

	print("RESULT: %s" % ("all checks passed" if _failed == 0 else "%d checks FAILED" % _failed))
	quit(_failed)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		_failed += 1
