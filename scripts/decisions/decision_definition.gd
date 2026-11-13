@tool
class_name DecisionDefinition
extends Resource
## What an NPC offers: who speaks, what they say and the options to pick from.

@export var id: String = ""
@export var speaker_name: String = ""
@export_multiline var prompt: String = ""
@export var options: Array[DecisionOption] = []
