class_name MovementConfig
extends Resource
## Movement tuning for a character.

## Walking speed in pixels per second.
@export_range(0.0, 500.0, 1.0, "suffix:px/s") var walk_speed: float = 150.0

## Running speed in pixels per second.
@export_range(0.0, 500.0, 1.0, "suffix:px/s") var run_speed: float = 220.0
