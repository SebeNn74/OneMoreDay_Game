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
