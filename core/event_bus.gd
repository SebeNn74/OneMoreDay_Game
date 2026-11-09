extends Node
## Global events bus. Only declares signals.

# --- Player ---

@warning_ignore("unused_signal")
signal player_interacted(target: Node)

# --- Levels ---

@warning_ignore("unused_signal")
signal level_completed

# --- Stats ---

## Emitted when a stat changes. [param change] is the change actually applied.
@warning_ignore("unused_signal")
signal stat_changed(type: StatDefinition.Type, new_value: float, change: float)

## Emitted once when a stat becomes depleted (e.g. energy reaches 0).
@warning_ignore("unused_signal")
signal stat_depleted(type: StatDefinition.Type)

# --- Day flow ---

## Emitted after a day step's scene is loaded and visible.
@warning_ignore("unused_signal")
signal day_step_started(step: DayStep)

## Emitted once when the day ends, before the end screen loads.
@warning_ignore("unused_signal")
signal day_finished(result: DayResult)

# --- Events and notifications ---

## A random event was drawn and applied. For logs and endings (which events happened).
@warning_ignore("unused_signal")
signal game_event_triggered(event: GameEvent)

## Asks the UI to show a message to the player and wait until it is closed.
@warning_ignore("unused_signal")
signal notification_requested(text: String)

## The player closed the notification.
@warning_ignore("unused_signal")
signal notification_closed
