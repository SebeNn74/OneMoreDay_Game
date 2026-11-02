class_name RandomWalk
extends RefCounted
## Grid random walk. Port of step() in simulation_standalone/jimenez_poveda_modelo2_caminata.py.
## Cells are tiles (Vector2i); the caller converts them to positions.


## Picks a direction with the configured probabilities.
static func choose_direction(config: RandomWalkConfig, rng: Lcg) -> Vector2i:
	var number: float = rng.next()
	var accumulated: float = 0.0
	var direction: Vector2i = Vector2i.ZERO
	for entry: Array in config.weighted_directions():
		direction = entry[0]
		accumulated += entry[1]
		if number < accumulated:
			return direction
	return direction  # R == 1.0


## Next cell. [param is_free] is a Callable(Vector2i) -> bool; blocked or outside moves keep the cell.
static func next_cell(cell: Vector2i, config: RandomWalkConfig, rng: Lcg, is_free: Callable) -> Vector2i:
	var target: Vector2i = cell + choose_direction(config, rng)
	return target if is_free.call(target) else cell
