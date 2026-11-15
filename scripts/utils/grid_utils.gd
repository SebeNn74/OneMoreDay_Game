class_name GridUtils
extends RefCounted
## Conversions between world positions and grid cells, used by agents that move by cells.

## Cell side in world pixels.
const CELL_SIZE: int = 32


## Cell that contains [param world_position].
static func cell_of(world_position: Vector2) -> Vector2i:
	return Vector2i((world_position / CELL_SIZE).floor())


## World position of the center of [param cell].
static func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE
