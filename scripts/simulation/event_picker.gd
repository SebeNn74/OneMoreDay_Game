class_name EventPicker
extends RefCounted
## Monte Carlo event selection. Port of draw_without_replacement() in
## simulation_standalone/jimenez_poveda_modelo3_montecarlo.py: weighted draw without
## replacement, so an event never repeats in the same day (tab 5 Reglas).

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
	var total_weight: int = 0
	for event: GameEvent in pool:
		total_weight += event.weight
	var target: float = rng.next() * total_weight
	var accumulated: int = 0
	for i: int in pool.size():
		accumulated += pool[i].weight
		if target < accumulated:
			return pool.pop_at(i)
	return pool.pop_back()  # R == 1.0
