class_name PlayerCamera
extends Camera2D
## Camera that follows the player.
## On an axis where the level is smaller than the screen, the level is centered.
## Until a level sets its bounds it stays locked to one screen.
## shake() jolts it for a moment (hits).

const SHAKE_SECONDS: float = 0.25

var _shake_strength: float = 0.0
var _shake_left: float = 0.0


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
	
## Jolts the camera by up to [param pixels] for SHAKE_SECONDS.
func shake(pixels: float) -> void:
	_shake_strength = maxf(_shake_strength if _shake_left > 0.0 else 0.0, pixels)
	_shake_left = SHAKE_SECONDS


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	var fade: float = maxf(_shake_left, 0.0) / SHAKE_SECONDS
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * fade


## Extra space on each side so a level smaller than the screen ends up centered.
## Zero when the level fills (or exceeds) the screen on that axis.
static func _centering_margin(level_length: int, screen_length: int) -> int:
	@warning_ignore("integer_division")
	return maxi(screen_length - level_length, 0) / 2
