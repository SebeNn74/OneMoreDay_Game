@tool
class_name DecisionOption
extends Resource
## One of the choices an NPC offers

@export var text: String = ""
@export var money: float = 0.0
@export var energy: float = 0.0
@export var time: float = 0.0
@export var queue: QueueConfig
## Route choice: picking this option leaves the level for this scene instead of the exit.
## A later step of the day is skipped to (taxi); any other scene replaces the next step (bus).
@export_file("*.tscn") var next_scene: String = ""
## Played on the way to next_scene (a Minigame scene: the bus or taxi ride). Its cost adds up.
@export var minigame: PackedScene

@export_group("Risk (Monte Carlo)")
## Chance that the bad outcome happens when this option is picked (0 = no risk).
## Drawn with the day's LCG and shown on the card, so taking the risk is a choice.
@export_range(0.0, 1.0, 0.05) var risk_chance: float = 0.0
## What goes wrong (player-visible, Spanish). Example: "se vara la moto".
@export var risk_text: String = ""
@export var risk_money: float = 0.0
@export var risk_energy: float = 0.0
@export var risk_time: float = 0.0

@export_group("Bonus by state")
## Extra effect when bonus_stat is below bonus_below at the moment of choosing (0 = no bonus).
@export var bonus_stat: StatDefinition.Type = StatDefinition.Type.ENERGY
@export var bonus_below: float = 0.0
## Why the bonus happens (player-visible, Spanish). Example: "te ve cansado y te sirve doble".
@export var bonus_text: String = ""
@export var bonus_money: float = 0.0
@export var bonus_energy: float = 0.0
@export var bonus_time: float = 0.0


func has_risk() -> bool:
	return risk_chance > 0.0


func has_bonus() -> bool:
	return bonus_below > 0.0
