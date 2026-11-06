extends Node
## Debug-only hotkeys to change stats while playing. Removed in non-debug builds.
## 1 / 2 / 3 = drain money / energy / time.  Shift + 1 / 2 / 3 = restore.

const MIN_PRINTED_CHANGE: float = 0.5

const BINDINGS: Dictionary = {
	KEY_1: { type = StatDefinition.Type.MONEY, step = 5.0 },
	KEY_2: { type = StatDefinition.Type.ENERGY, step = 25.0 },
	KEY_3: { type = StatDefinition.Type.TIME, step = 25.0 },
}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	EventBus.stat_changed.connect(_on_stat_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if not BINDINGS.has(key_event.physical_keycode):
		return

	var binding: Dictionary = BINDINGS[key_event.physical_keycode]
	var direction: float = 1.0 if key_event.shift_pressed else -1.0
	StatsManager.modify(binding.type, direction * binding.step)


func _on_stat_changed(type: StatDefinition.Type, new_value: float, change: float) -> void:
	if absf(change) < MIN_PRINTED_CHANGE:
		return
	print("[Debug] %s = %s (%+.0f)" % [StatDefinition.Type.keys()[type], new_value, change])
