@tool
class_name EndingCatalog
extends Resource
## All the endings plus the thresholds their conditions use.

@export var endings: Array[EndingDefinition] = []

@export_group("Rules")
## V-04: spare seconds on the clock when El Marcador is beaten.
@export var challenge_spare_seconds: float = 15.0
## V-05: money at home (units of $1.000).
@export var rich_money: float = 25.0
## V-01: minimum money, energy and time at home.
@export var comfort_money: float = 10.0
@export var comfort_energy: float = 20.0
@export var comfort_time: float = 10.0


## Returns the ending with that id, or null (with an error) if there is none.
func find(id: String) -> EndingDefinition:
	for ending: EndingDefinition in endings:
		if ending.id == id:
			return ending
	push_error("EndingCatalog: unknown ending '%s'." % id)
	return null
