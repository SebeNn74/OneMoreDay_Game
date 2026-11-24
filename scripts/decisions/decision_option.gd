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
