class_name ItemDefinition
extends Resource
## Data of an object lying in a level: coin, bill, coffee....

@export var id: String = ""
@export var display_name: String = ""
@export var action_text: String = ""

@export_group("Effect")
## Negative = it costs the player.
@export var money: float = 0.0
@export var energy: float = 0.0
@export var time: float = 0.0

@export_group("Visual")
@export var sprite_animation: StringName = &""
