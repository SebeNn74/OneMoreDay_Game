class_name PlayerCamera
extends Camera2D
## Camera that follows the player.
## Until a level sets its bounds it stays locked to one screen, so scenes that
## do not call set_level_bounds() (home, collision_test) behave as before.


func _ready() -> void:
	set_level_bounds(Vector2i(get_viewport_rect().size))


## Limits the camera to the rectangle (0, 0) - level_size. Called by BaseLevel.
func set_level_bounds(level_size: Vector2i) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = level_size.x
	limit_bottom = level_size.y
