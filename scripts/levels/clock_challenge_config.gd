class_name ClockChallengeConfig
extends Resource
## Balanceable parameters of El Marcador.

## Name for logs and the endings.
@export var display_name: String = ""

@export_group("Rules")
## Real seconds on the clock.
@export_range(5.0, 300.0, 1.0, "suffix:s") var duration_seconds: float = 45.0
@export_range(1, 10, 1) var folder_count: int = 3
## Seconds a hostile hit takes off the clock.
@export_range(0.0, 30.0, 0.5, "suffix:s") var hit_penalty_seconds: float = 3.0
## The hostiles of the level walk at this fraction of their usual speed (fairness: the player
## has to cross the whole office several times).
@export_range(0.3, 1.5, 0.05) var hostile_speed_scale: float = 1.0
## Money bonus for delivering on time.
@export var bonus_money: float = 10.0
## TIME the stat loses over the whole duration: the design cost of one scenario (tab "Guía": 6).
@export var time_cost: float = 6.0
## Clock seconds a queue wait costs per time unit waited.
@export_range(0.0, 30.0, 0.5, "suffix:s") var wait_seconds_per_unit: float = 3.0

@export_group("Content")
## The folders to collect (an item with no effects).
@export var folder_item: ItemDefinition
## The decision that delivers them. It must be the one the delivery point offers.
@export var delivery_decision: DecisionDefinition
## Shown before the clock starts.
@export_multiline var intro_text: String = ""
