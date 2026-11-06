class_name PlayerSimulationBridge
extends Node
## Connects the player with the resource dynamics of the Simulation autoload.
## Every physics frame it reports what the player is doing and applies the fatigue speed factor.

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	assert(_player != null, "PlayerSimulationBridge must be a child of Player.")


func _physics_process(_delta: float) -> void:
	if not _player.is_controllable():
		return
	Simulation.set_player_activity(_activity_of(_player.state_machine.current_state))
	_player.speed_multiplier = Simulation.speed_factor()


func _activity_of(state: PlayerState.Type) -> ResourceDynamics.Activity:
	match state:
		PlayerState.Type.WALK:
			return ResourceDynamics.Activity.WALK
		PlayerState.Type.RUN:
			return ResourceDynamics.Activity.RUN
	return ResourceDynamics.Activity.IDLE
