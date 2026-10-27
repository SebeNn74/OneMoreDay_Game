class_name StatDefinition
extends Resource
## Static configuration of a game stat (money, energy, time).

enum Type { MONEY, ENERGY, TIME }

@export var type: Type = Type.MONEY

@export_group("Display")
## Name shown to the player (Spanish).
@export var display_name: String = ""
@export var icon: Texture2D

@export_group("Rules")
@export var initial_value: float = 0.0
## If false, the value is clamped at 0.
@export var allow_negative: bool = false
@export var has_max_value: bool = false
@export var max_value: float = 100.0


## Applies this stat's limits to a raw value.
func clamp_value(raw_value: float) -> float:
	var min_limit: float = -INF if allow_negative else 0.0
	var max_limit: float = max_value if has_max_value else INF
	return clampf(raw_value, min_limit, max_limit)


## A stat that can go negative is depleted when in debt (< 0).
## A stat clamped at 0 is depleted when it reaches 0 (<= 0).
func is_depleted_at(value: float) -> bool:
	if allow_negative:
		return value < 0.0
	return value <= 0.0
