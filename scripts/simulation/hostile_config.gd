class_name HostileConfig
extends Resource
## Behaviour parameters of a hostile agent (catalog in OneMoreDay_Diseño.xlsx, tab 5).

## false: wanderer (always random walk, e.g. H-T2). true: chaser (e.g. H-T1, H-I3, H-V3).
@export var chases: bool = false
## Manhattan distance in cells at which a chaser notices the player.
## Model 4 calibration: r = 0-1 keeps P(hit) close to the design (30-40 %) for a player who does not dodge.
@export_range(0, 10, 1) var vision_radius: int = 1
## Probability of advancing each tick while chasing (lower = slower than the player).
@export_range(0.0, 1.0, 0.05) var chase_probability: float = 0.6
## A chaser gives up when the player is farther than vision_radius + lose_margin.
@export_range(0, 10, 1) var lose_margin: int = 2
@export var patrol: RandomWalkConfig
