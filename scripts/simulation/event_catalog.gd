class_name EventCatalog
extends Resource
## All the random events of the game (data/events/event_catalog.tres).

@export var events: Array[GameEvent] = []


## A new array each call, so callers can remove events from it.
func of_stage(stage: GameEvent.Stage) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	result.assign(events.filter(func(event: GameEvent) -> bool: return event.stage == stage))
	return result
