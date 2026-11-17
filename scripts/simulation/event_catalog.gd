class_name EventCatalog
extends Resource
## All the random events of the game (data/events/event_catalog.tres).

@export var events: Array[GameEvent] = []
## Sampler of model 3. 0 = direct weighted draw (classic Monte Carlo, inverse transform).
## > 0 = Metropolis-Hastings chain of this many steps (MCMC). The game pools reach a total
## variation distance below 1e-3 from π in 5 steps (simulation_standalone, modelo3).
@export_range(0, 100, 1) var mcmc_steps: int = 10


## A new array each call, so callers can remove events from it.
func of_stage(stage: GameEvent.Stage) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	result.assign(events.filter(func(event: GameEvent) -> bool: return event.stage == stage))
	return result
