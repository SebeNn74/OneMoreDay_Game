class_name QueueConfig
extends Resource
## Parameters of an M/M/1 queue (bus stop, printer queue, delivery point).
## Rates are per game time unit (TIME 0-100 = the whole day), so the wait is in TIME units.

## Spanish name shown to the player. Example: "Paradero".
@export var display_name: String = ""
## λ: people arriving per time unit.
@export_range(0.0, 10.0, 0.01) var arrival_rate: float = 0.8
## μ: people served per time unit. Must be greater than arrival_rate.
@export_range(0.01, 10.0, 0.01) var service_rate: float = 1.0
