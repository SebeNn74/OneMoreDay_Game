class_name RandomWalkConfig
extends Resource
## Direction probabilities of a grid random walk. They must add up to 1.

@export_range(0.0, 1.0, 0.01) var up: float = 0.25
@export_range(0.0, 1.0, 0.01) var down: float = 0.25
@export_range(0.0, 1.0, 0.01) var left: float = 0.25
@export_range(0.0, 1.0, 0.01) var right: float = 0.25


## Same order as the Python model (up, down, left, right), so a seed gives the same steps.
func weighted_directions() -> Array:
	return [[Vector2i.UP, up], [Vector2i.DOWN, down], [Vector2i.LEFT, left], [Vector2i.RIGHT, right]]
