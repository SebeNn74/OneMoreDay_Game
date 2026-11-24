extends SceneTree
## Checks the queue of "La carta a García": a robot clerk with exponential service (rate MU) must
## measure what the M/M/1 theory predicts for λ = ARRIVAL_RATE (ρ = λ / MU).
## Run: godot --headless --path . -s res://tools/letter_queue_self_test.gd

const MU: float = 2.0
const SIMULATED_SECONDS: float = 20000.0  # Long: a time average of a queue converges slowly.
const STEP: float = 0.02
const TOLERANCE: float = 0.12

var _failed: int = 0


func _initialize() -> void:
	await process_frame  # Autoloads are ready.
	var rng: Lcg = root.get_node("Simulation").rng
	var game: Node = load("res://scripts/minigames/letter_garcia_minigame.gd").new()
	game.set("_rng", rng)
	game.set("_next_arrival", rng.exponential(game.ARRIVAL_RATE))
	var service_left: float = -1.0
	var elapsed: float = 0.0
	while elapsed < SIMULATED_SECONDS:
		game.call("_advance", STEP)
		elapsed += STEP
		var line: Array = game.get("_queue")
		if line.is_empty():
			service_left = -1.0
			continue
		if service_left < 0.0:
			service_left = rng.exponential(MU)
		service_left -= STEP
		if service_left <= 0.0:
			game.call("_dispatch", int(line[0].dest))  # The robot never misses.
			service_left = -1.0
	_check("μ̂ close to %.2f" % MU, game.call("measured_service_rate"), MU)
	# The game compares with the theory at the measured μ̂, so the test does the same.
	var theory: Dictionary = game.call("theory")
	_check("Lq close to ρ²/(1-ρ) = %.2f (ρ = %.2f)" % [theory.lq, theory.rho], game.call("measured_lq"), theory.lq)
	_check("Wq close to Lq/λ = %.2f s" % theory.wq, game.call("measured_wq"), theory.wq)
	# A full line (MAX_QUEUE letters) is rare: about ρ^MAX_QUEUE of the arrivals overflow (0.2 %).
	var overflow_share: float = float(game.get("_overflow")) / float(game.get("_arrived"))
	var rare: bool = overflow_share < 0.01
	print("  [%s] overflow share %.4f (theory about %.4f, must stay under 1 %%)" % [
		"OK" if rare else "FAIL", overflow_share, pow(theory.rho, game.MAX_QUEUE)])
	if not rare:
		_failed += 1
	print("RESULT: %s" % ("all checks passed" if _failed == 0 else "%d checks FAILED" % _failed))
	game.free()
	quit(_failed)


func _check(label: String, measured: float, expected: float) -> void:
	var ok: bool = absf(measured - expected) <= TOLERANCE * maxf(absf(expected), 1.0)
	print("  [%s] %s: measured %.3f" % ["OK" if ok else "FAIL", label, measured])
	if not ok:
		_failed += 1
