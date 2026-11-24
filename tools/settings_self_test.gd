extends SceneTree
## Checks key rebinding of the Settings autoload (swap, steal a secondary key, reset).
## Run: godot --headless --path . -s res://tools/settings_self_test.gd
## Does not save, so user://settings.cfg is not touched.

var _failed: int = 0


func _initialize() -> void:
	await process_frame  # Autoloads are ready.
	var settings: Node = root.get_node("Settings")
	settings.reset_bindings()

	_check("default interact is E", settings.primary_key(&"interact") == KEY_E)
	_check("hint uses the keys", settings.with_keys("[{interact}] Seguir") == "[E] Seguir")

	settings.rebind(&"interact", KEY_F)
	_check("interact moves to F", settings.primary_key(&"interact") == KEY_F)
	_check("prompt follows the new key", settings.with_keys("[{interact}]") == "[F]")

	settings.rebind(&"run", KEY_F)  # F belongs to interact: they swap.
	_check("run takes F", settings.primary_key(&"run") == KEY_F)
	_check("interact gets Shift back (swap)", settings.primary_key(&"interact") == KEY_SHIFT)

	settings.rebind(&"pause", KEY_SPACE)  # Space is interact's second key: interact loses it.
	_check("pause takes Space", settings.primary_key(&"pause") == KEY_SPACE)
	_check("Space no longer interacts", not _has_key(&"interact", KEY_SPACE))
	_check("arrows still move", _has_key(&"move_up", KEY_UP))

	settings.reset_bindings()
	_check("reset restores E", settings.primary_key(&"interact") == KEY_E)
	_check("reset restores Space", _has_key(&"interact", KEY_SPACE))
	_check("gamepad A interacts", _has_joy_button(&"interact", JOY_BUTTON_A))
	_check("model panel is an action on M", settings.primary_key(&"toggle_models") == KEY_M)
	_check("model panel hint", settings.with_keys("[{models}]") == "[M]")

	print("RESULT: %s" % ("all checks passed" if _failed == 0 else "%d checks FAILED" % _failed))
	quit(_failed)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		_failed += 1


func _has_key(action: StringName, physical: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == physical:
			return true
	return false


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false
