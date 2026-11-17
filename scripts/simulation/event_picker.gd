class_name EventPicker
extends RefCounted
## Monte Carlo event selection. Port of draw_without_replacement() in
## simulation_standalone/jimenez_poveda_modelo3_montecarlo_mcmc.py: weighted draw without
## replacement, so an event never repeats in the same day (tab 5 Reglas).
## Each draw samples π_i = w_i / Σw over the events still available in the stage, either directly
## (EventCatalog.mcmc_steps = 0) or with a Metropolis-Hastings chain (MetropolisSampler).

var _catalog: EventCatalog
# Maps GameEvent.Stage -> Array[GameEvent] still available today.
var _pools: Dictionary = {}


func _init(catalog: EventCatalog) -> void:
	_catalog = catalog
	reset_day()


## Refills every pool. Call it at the start of each day.
func reset_day() -> void:
	for stage: int in GameEvent.Stage.values():
		_pools[stage] = _catalog.of_stage(stage)


## Draws and removes one event of [param stage]. Returns null when the stage has no events left.
func draw(stage: GameEvent.Stage, rng: Lcg) -> GameEvent:
	var pool: Array[GameEvent] = _pools[stage]
	if pool.is_empty():
		return null
	var weights: Array[float] = []
	for event: GameEvent in pool:
		weights.append(float(event.weight))
	var index: int
	if _catalog.mcmc_steps > 0:
		index = MetropolisSampler.sample(weights, _catalog.mcmc_steps, rng)
	else:
		index = _direct_index(weights, rng)
	return pool.pop_at(index)


## Inverse transform over the cumulative weights (classic Monte Carlo).
static func _direct_index(weights: Array[float], rng: Lcg) -> int:
	var total_weight: float = 0.0
	for weight: float in weights:
		total_weight += weight
	var target: float = rng.next() * total_weight
	var accumulated: float = 0.0
	for i: int in weights.size():
		accumulated += weights[i]
		if target < accumulated:
			return i
	return weights.size() - 1  # R == 1.0
