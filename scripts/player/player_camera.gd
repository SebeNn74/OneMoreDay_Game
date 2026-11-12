class_name PlayerCamera
extends Camera2D
## Camera that follows the player.
## On an axis where the level is smaller than the screen, the level is centered.
## Until a level sets its bounds it stays locked to one screen.


func _ready() -> void:
	set_level_bounds(Vector2i(get_viewport_rect().size))


## Limits the camera to the rectangle (0, 0) - level_size. Called by BaseLevel.
func set_level_bounds(level_size: Vector2i) -> void:
	var screen_size: Vector2i = Vector2i(get_viewport_rect().size)
	var margin: Vector2i = Vector2i(
		_centering_margin(level_size.x, screen_size.x),
		_centering_margin(level_size.y, screen_size.y)
	)
	limit_left = -margin.x
	limit_top = -margin.y
	limit_right = level_size.x + margin.x
	limit_bottom = level_size.y + margin.y
	
## Extra space on each side so a level smaller than the screen ends up centered.
## Zero when the level fills (or exceeds) the screen on that axis.
static func _centering_margin(level_length: int, screen_length: int) -> int:
	@warning_ignore("integer_division")
	return maxi(screen_length - level_length, 0) / 2
