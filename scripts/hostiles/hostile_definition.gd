class_name HostileDefinition
extends Resource
## Game-facing data of one hostile type.
## The behavior (wander or chase, vision radius, pursuit speed) is HostileConfig;
## this resource adds what a hit costs, the step speed and the placeholder look.

@export var id: String = ""
@export var display_name: String = ""
@export var behavior: HostileConfig

@export_group("Hit")
## Effect of one hit on each stat. Negative = the player loses it.
@export var hit_money: float = 0.0
@export var hit_energy: float = 0.0
@export var hit_time: float = 0.0

@export_group("Movement")
## Seconds per cell step. One tick = one cell (GridUtils.CELL_SIZE px).
@export_range(0.05, 2.0, 0.05, "suffix:s") var tick_seconds: float = 0.25

@export_group("Placeholder")
@export var placeholder_color: Color = Color(0.85, 0.25, 0.25)
