class_name PlayerSimulationBridge
extends Node
## Connects the player with the resource dynamics of the Simulation autoload.
## Every physics frame it reports what the player is doing and applies the fatigue speed factor.

## Resting ends on its own this close to full energy: the recovery is exponential and never
## reaches the maximum, so without a margin the player would keep spending time for nothing.
const FULL_ENERGY_MARGIN: float = 2.0

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	assert(_player != null, "PlayerSimulationBridge must be a child of Player.")


func _physics_process(_delta: float) -> void:
	if not _player.is_controllable():
		return
	if _player.is_resting and _is_energy_full():
		_player.stop_resting()
	Simulation.set_player_activity(_activity_of(_player.state_machine.current_state))
	_player.speed_multiplier = Simulation.speed_factor()


func _activity_of(state: PlayerState.Type) -> ResourceDynamics.Activity:
	match state:
		PlayerState.Type.WALK:
			return ResourceDynamics.Activity.WALK
		PlayerState.Type.RUN:
			return ResourceDynamics.Activity.RUN
	if _player.is_resting:
		return ResourceDynamics.Activity.REST
	return ResourceDynamics.Activity.IDLE


func _is_energy_full() -> bool:
	var max_energy: float = StatsManager.get_definition(StatDefinition.Type.ENERGY).max_value
	return StatsManager.get_value(StatDefinition.Type.ENERGY) >= max_energy - FULL_ENERGY_MARGIN
