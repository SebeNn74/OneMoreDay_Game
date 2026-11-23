extends SceneTree
## Headless test of the ending rules (EndingResolver) against the catalog thresholds.
## Run from the project folder (the catalog must exist: run generate_ending_catalog.gd first):

const CATALOG_PATH: String = "res://data/endings/ending_catalog.tres"
## A healthy day: overridden by each case.
const BASE: Dictionary = { money = 30.0, energy = 60.0, time = 40.0 }

var _catalog: EndingCatalog
var _failures: int = 0


func _initialize() -> void:
	print("Ending self-test")
	_catalog = load(CATALOG_PATH) as EndingCatalog
	_check("catalog loads", _catalog != null, "")
	if _catalog == null:
		quit(1)
		return
	for id: String in ["V-01", "V-02", "V-03", "V-04", "V-05", "D-01", "D-02", "D-03", "D-04", "D-05"]:
		var ending: EndingDefinition = _catalog.find(id)
		_check("%s exists with text and image" % id,
			ending != null and not ending.text.is_empty() and ending.image != null, "")

	var money: int = StatDefinition.Type.MONEY
	var energy: int = StatDefinition.Type.ENERGY
	var time: int = StatDefinition.Type.TIME
	# Victories.
	_case("default victory (money 30) is V-05", "V-05", { is_victory = true })
	_case("comfortable day is V-01", "V-01", { is_victory = true, money = 12.0, energy = 25.0, time = 15.0 })
	_case("low energy at home is V-02", "V-02", { is_victory = true, money = 12.0, energy = 15.0 })
	_case("helping is V-03", "V-03", { is_victory = true, helped = true })
	_case("V-03 wins over V-04", "V-03", { is_victory = true, helped = true,
		challenge_success = true, challenge_seconds_left = 20.0 })
	_case("20 s to spare is V-04", "V-04", { is_victory = true, challenge_success = true,
		challenge_seconds_left = 20.0 })
	_case("exactly 15 s is V-04", "V-04", { is_victory = true, challenge_success = true,
		challenge_seconds_left = 15.0 })
	_case("14.9 s falls to V-05", "V-05", { is_victory = true, challenge_success = true,
		challenge_seconds_left = 14.9 })
	# Defeats.
	_case("money without theft is D-01", "D-01", { depleted_stat = money })
	_case("energy is D-02", "D-02", { depleted_stat = energy })
	_case("time is D-03", "D-03", { depleted_stat = time })
	_case("money after a theft is D-04", "D-04", { depleted_stat = money, last_money_loss_was_theft = true })
	_case("clock failure is D-05", "D-05", { challenge_failed = true })
	_case("energy during the challenge is D-05", "D-05", { depleted_stat = energy, challenge_active = true })
	_case("D-04 wins over D-05", "D-04", { depleted_stat = money, last_money_loss_was_theft = true,
		challenge_active = true })
	_case("D-05 wins over D-01", "D-05", { depleted_stat = money, challenge_failed = true })
	_case("time during the challenge is D-03", "D-03", { depleted_stat = time, challenge_active = true })

	print("RESULT: %s" % ("all checks passed" if _failures == 0 else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _case(case_name: String, expected_id: String, overrides: Dictionary) -> void:
	var fields: Dictionary = BASE.duplicate()
	fields.merge(overrides, true)
	var summary: RunSummary = RunSummary.new()
	for key: String in fields:
		summary.set(key, fields[key])
	var ending: EndingDefinition = EndingResolver.resolve(summary, _catalog)
	var actual_id: String = ending.id if ending != null else "null"
	_check(case_name, actual_id == expected_id, "expected %s, got %s" % [expected_id, actual_id])


func _check(check_name: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("  [%s] %s %s" % ["OK" if passed else "FAIL", check_name, "" if passed else "-> " + detail])
