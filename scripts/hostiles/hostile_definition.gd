class_name HostileDefinition
extends Resource
## Game-facing data of one hostile type.
## The behavior (wander or chase, vision radius, pursuit speed) is HostileConfig;
## this resource adds what a hit costs, the step speed and the sprite appearance.

@export var id: String = ""
@export var display_name: String = ""
@export var behavior: HostileConfig
@export var sprite_frames: SpriteFrames
## Directional sheets use a base name; other sheets use the exact animation name.
@export var sprite_animation: StringName = &""

@export_group("Appearance")
## Extra size multiplier applied after fitting the sprite width to a grid cell.
@export_range(0.25, 4.0, 0.05, "suffix:x") var sprite_scale: float = 1.0
## Hitbox dimensions in pixels at sprite_scale = 1.0.
@export var hitbox_size: Vector2 = Vector2(24.0, 24.0)
## Hitbox position relative to the hostile's cell; scales with sprite_scale.
@export var hitbox_offset: Vector2 = Vector2(0.0, -12.0)

@export_group("Hit")
## Effect of one hit on each stat. Negative = the player loses it.
@export var hit_money: float = 0.0
@export var hit_energy: float = 0.0
@export var hit_time: float = 0.0
## Seconds after a hit before this hostile can hit again (it keeps moving meanwhile).
@export_range(0.5, 30.0, 0.5, "suffix:s") var hit_cooldown_seconds: float = 3.0
## How hard a hit pushes the player back (1 = a person, more for vehicles).
@export_range(0.0, 4.0, 0.1) var knockback_strength: float = 1.0

@export_group("Movement")
## Seconds per cell step. One tick = one cell (GridUtils.CELL_SIZE px).
@export_range(0.05, 2.0, 0.05, "suffix:s") var tick_seconds: float = 0.25

@export_group("Lane")
## Vehicles drive straight along their road instead of walking cell by cell. Each one crosses,
## leaves, and comes back after an exponential gap: the crossings form a Poisson process.
@export var drives_in_lane: bool = false
@export_range(30.0, 800.0, 10.0, "suffix:px/s") var lane_speed: float = 240.0
## Mean seconds between two crossings of the same vehicle (1 / λ).
@export_range(0.5, 30.0, 0.5, "suffix:s") var mean_gap_seconds: float = 3.0
