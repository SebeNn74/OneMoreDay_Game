@tool
class_name DecisionOption
extends Resource
## One of the choices an NPC offers

@export var text: String = ""
@export var money: float = 0.0
@export var energy: float = 0.0
@export var time: float = 0.0
@export var queue: QueueConfig
