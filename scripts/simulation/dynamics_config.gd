class_name DynamicsConfig
extends Resource
## Parameters of the resource system dynamics (model 5).
## Calibration: walking across one scenario at normal energy costs exactly the design base
## consumption (OneMoreDay_Diseño.xlsx, Guía): base_energy_cost and base_time_cost.

## Pixels walked to cross one scenario (one screen).
@export var scenario_length: float = 640.0
@export var base_energy_cost: float = 5.0
@export var base_time_cost: float = 6.0
## Running drains energy this many times faster than walking.
@export_range(1.0, 5.0, 0.1) var run_drain_factor: float = 1.8
## Below this energy the character slows down (fatigue feedback loop).
@export_range(0.0, 100.0, 1.0) var fatigue_threshold: float = 30.0
## Slowest speed, as a fraction of the normal one.
@export_range(0.0, 1.0, 0.05) var min_speed_factor: float = 0.4
## r in dE/dt = r (E_max - E) while resting.
@export_range(0.0, 1.0, 0.01) var rest_rate: float = 0.15
