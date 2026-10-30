class_name InteractionDetector
extends Area2D
## Finds the closest Interactable in front of the player.
## Child of Player; its position follows the facing direction (see face()).

## Emitted when the focused target changes. [param target] is null when none.
signal focus_changed(target: Interactable)

## Distance from the body center to the detector center, in pixels.
@export var reach: float = 16.0
## Body center relative to the player's origin (the feet).
@export var body_center_offset: Vector2 = Vector2(0.0, -12.0)

var current_target: Interactable


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.INTERACTABLES


func _physics_process(_delta: float) -> void:
	_set_target(_find_closest_target())


## Moves the detector in front of the player.
func face(direction: Vector2) -> void:
	position = body_center_offset + direction * reach


## Interacts with the focused target. Returns false if there is none.
func interact(interactor: Node) -> bool:
	if current_target == null:
		return false
	current_target.interact(interactor)
	return true


func _find_closest_target() -> Interactable:
	var closest: Interactable = null
	var closest_distance: float = INF

	for area: Area2D in get_overlapping_areas():
		var candidate: Interactable = area as Interactable
		if candidate == null or not candidate.is_available():
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < closest_distance:
			closest = candidate
			closest_distance = distance

	return closest


func _set_target(new_target: Interactable) -> void:
	if new_target == current_target:
		return
	current_target = new_target
	focus_changed.emit(current_target)
