extends SceneTree
## Checks the random walk of "Caza bandidos": the mean number of steps to cross the forehead must be
## close to COLUMNS / (P_RIGHT - P_LEFT). The wall on the left pushes the walk forward a little, so the
## measured mean is a bit below the theory (about 2 %).
## Run: godot --headless --path . -s res://tools/bandit_walk_self_test.gd

const BANDITS: int = 2000
const TOLERANCE: float = 0.05


func _initialize() -> void:
	await process_frame  # Autoloads are ready.
	var game: Node = load("res://scripts/minigames/bandit_hunt_minigame.gd").new()
	game.set("_rng", root.get_node("Simulation").rng)
	var holder: Node2D = Node2D.new()
	root.add_child(holder)
	game.set("_people", holder)
	for i: int in BANDITS:
		game.call("_spawn")
		while not (game.get("_bandits") as Array).is_empty():
			game.call("_step_all")
	var steps: Array = game.get("_escape_steps")
	var total: int = 0
	for value: int in steps:
		total += value
	var mean: float = float(total) / steps.size()
	var theory: float = game.COLUMNS / (game.P_RIGHT - game.P_LEFT)
	var difference: float = absf(mean - theory) / theory
	var passed: bool = steps.size() == BANDITS and difference <= TOLERANCE
	print("  [%s] %d bandits crossed in %.2f steps on average (theory %.2f, %.1f %% off)" % [
		"OK" if passed else "FAIL", steps.size(), mean, theory, difference * 100.0])
	print("RESULT: %s" % ("all checks passed" if passed else "1 check FAILED"))
	game.free()
	quit(0 if passed else 1)
