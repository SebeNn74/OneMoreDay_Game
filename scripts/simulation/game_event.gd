class_name GameEvent
extends Resource
## One random event of the day (OneMoreDay_Diseño.xlsx, tab 3 Eventos).

enum Stage { HOME, COMMUTE, WORK, RETURN }

@export var id: String = ""
@export var stage: Stage = Stage.HOME
## Notification text shown to the player (Spanish, max. 90 characters).
@export_multiline var text: String = ""
@export var money: float = 0.0
@export var energy: float = 0.0
@export var time: float = 0.0
## Relative frequency inside its stage (1-3).
@export_range(1, 3, 1) var weight: int = 1
