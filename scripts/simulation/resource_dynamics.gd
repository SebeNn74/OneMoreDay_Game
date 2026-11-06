class_name ResourceDynamics
extends RefCounted
## Continuous flows of energy and time (model 5). Port of derivatives() and euler_step() in
## simulation_standalone/jimenez_poveda_modelo5_dinamica.py.
##   dT/dt = -c (the clock always runs)
##   dE/dt = -k (walk), -k * run_drain_factor (run), 0 (idle), r (E_max - E) (rest)
## The caller integrates with Euler: change = rate * delta, applied through StatsManager.

enum Activity { IDLE, WALK, RUN, REST }

var config: DynamicsConfig
## k: energy per second while walking.
var drain: float
## c: time units per second.
var clock: float


func _init(dynamics_config: DynamicsConfig, walk_speed: float) -> void:
	config = dynamics_config
	var walk_crossing_seconds: float = config.scenario_length / walk_speed
	drain = config.base_energy_cost / walk_crossing_seconds
	clock = config.base_time_cost / walk_crossing_seconds


## Rate of change of energy for the activity (energy per second).
func energy_rate(energy: float, max_energy: float, activity: Activity) -> float:
	match activity:
		Activity.WALK:
			return -drain
		Activity.RUN:
			return -drain * config.run_drain_factor
		Activity.REST:
			return config.rest_rate * (max_energy - energy)
	return 0.0


## Rate of change of time (time units per second).
func time_rate() -> float:
	return -clock


## Multiplier of the movement speed: 1 above the fatigue threshold, E / threshold below it.
func speed_factor(energy: float) -> float:
	if energy >= config.fatigue_threshold:
		return 1.0
	return maxf(config.min_speed_factor, energy / config.fatigue_threshold)


## E* = sqrt(2 * base_energy_cost * threshold). Below it, a walking crossing runs out of
## energy before the exit unless the player rests. Useful for a low-energy warning.
func critical_energy() -> float:
	return sqrt(2.0 * config.base_energy_cost * config.fatigue_threshold)
