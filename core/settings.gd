extends Node
## Autoload. Player options: music and effects volume, fullscreen and key bindings.
## Saved to user://settings.cfg and applied at startup. Loads before AudioManager, which plays
## through the MUSIC_BUS and SFX_BUS buses created here.

const CONFIG_PATH: String = "user://settings.cfg"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 0.8
const FULLSCREEN_KEY: Key = KEY_F11
const MODELS_KEY: Key = KEY_M

## Actions the player can rebind, in the order the options screen lists them.
const REBINDABLE: Array[StringName] = [
	InputActions.MOVE_UP, InputActions.MOVE_DOWN, InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
	InputActions.INTERACT, InputActions.RUN, InputActions.PAUSE, InputActions.TOGGLE_MODELS,
]
## Player-visible texts (Spanish).
const ACTION_NAMES: Dictionary = {
	InputActions.MOVE_UP: "Arriba",
	InputActions.MOVE_DOWN: "Abajo",
	InputActions.MOVE_LEFT: "Izquierda",
	InputActions.MOVE_RIGHT: "Derecha",
	InputActions.INTERACT: "Interactuar",
	InputActions.RUN: "Correr",
	InputActions.PAUSE: "Pausa",
	InputActions.TOGGLE_MODELS: "Panel de modelos",
}
const KEY_NAMES: Dictionary = {
	"Space": "Espacio", "Escape": "Esc", "Enter": "Enter", "Up": "Flecha arriba",
	"Down": "Flecha abajo", "Left": "Flecha izq.", "Right": "Flecha der.", "Tab": "Tab",
}
## Tokens for with_keys(): "{interact}" becomes the current key of that action.
const KEY_TOKENS: Dictionary = {
	"up": InputActions.MOVE_UP, "down": InputActions.MOVE_DOWN, "left": InputActions.MOVE_LEFT,
	"right": InputActions.MOVE_RIGHT, "interact": InputActions.INTERACT, "run": InputActions.RUN,
	"pause": InputActions.PAUSE, "models": InputActions.TOGGLE_MODELS,
}
## Gamepad: d-pad and left stick move, A interacts, RB runs, Start pauses.
const JOY_BUTTONS: Dictionary = {
	InputActions.MOVE_UP: JOY_BUTTON_DPAD_UP, InputActions.MOVE_DOWN: JOY_BUTTON_DPAD_DOWN,
	InputActions.MOVE_LEFT: JOY_BUTTON_DPAD_LEFT, InputActions.MOVE_RIGHT: JOY_BUTTON_DPAD_RIGHT,
	InputActions.INTERACT: JOY_BUTTON_A, InputActions.RUN: JOY_BUTTON_RIGHT_SHOULDER,
	InputActions.PAUSE: JOY_BUTTON_START, InputActions.TOGGLE_MODELS: JOY_BUTTON_BACK,
}
const JOY_AXES: Dictionary = {
	InputActions.MOVE_UP: [JOY_AXIS_LEFT_Y, -1.0], InputActions.MOVE_DOWN: [JOY_AXIS_LEFT_Y, 1.0],
	InputActions.MOVE_LEFT: [JOY_AXIS_LEFT_X, -1.0], InputActions.MOVE_RIGHT: [JOY_AXIS_LEFT_X, 1.0],
}

signal bindings_changed

var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var fullscreen: bool = false

## Input Map events of each rebindable action as the project defines them (plus the gamepad).
var _default_events: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # F11 works in the pause menu too.
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_add_models_action()
	_add_gamepad_events()
	for action: StringName in REBINDABLE:
		_default_events[action] = InputMap.action_get_events(action)
	_load()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.echo and key.physical_keycode == FULLSCREEN_KEY:
		set_fullscreen(not fullscreen)
		save()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volume(SFX_BUS, sfx_volume)


func set_fullscreen(is_fullscreen: bool) -> void:
	fullscreen = is_fullscreen
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Main keyboard key of [param action] (the first key event in the Input Map).
func primary_key(action: StringName) -> Key:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return KEY_NONE


## Player-visible name of the main key of [param action] ("E", "Shift", "Espacio").
func key_name(action: StringName) -> String:
	var physical: Key = primary_key(action)
	if physical == KEY_NONE:
		return "-"
	# The name on the player's keyboard layout (headless runs have no layout: US names).
	var keycode: Key = physical if DisplayServer.get_name() == "headless" \
			else DisplayServer.keyboard_get_keycode_from_physical(physical)
	var label: String = OS.get_keycode_string(keycode)
	return KEY_NAMES.get(label, label)


## Replaces {interact}, {run}, {pause}, {models}, {up}, {down}, {left} and {right} with the current keys.
func with_keys(text: String) -> String:
	var names: Dictionary = {}
	for token: String in KEY_TOKENS:
		names[token] = key_name(KEY_TOKENS[token])
	return text.format(names)


## Makes [param physical] the main key of [param action]. The key leaves any other action; if it
## was another action's main key, that action gets this one's old key (a swap), so no action is
## left without a key and no key does two things.
func rebind(action: StringName, physical: Key) -> void:
	var old: Key = primary_key(action)
	if physical == old:
		return
	for other: StringName in REBINDABLE:
		if other == action:
			continue
		for event: InputEvent in InputMap.action_get_events(other):
			var key: InputEventKey = event as InputEventKey
			if key == null or key.physical_keycode != physical:
				continue
			if physical == primary_key(other) and old != KEY_NONE:
				_set_primary(other, old)
			else:
				InputMap.action_erase_event(other, key)
	_set_primary(action, physical)
	bindings_changed.emit()


func reset_bindings() -> void:
	for action: StringName in REBINDABLE:
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_events[action]:
			InputMap.action_add_event(action, event)
	bindings_changed.emit()


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	for action: StringName in REBINDABLE:
		config.set_value("keys", action, primary_key(action))
	var error: Error = config.save(CONFIG_PATH)
	if error != OK:
		push_warning("Settings: could not save %s (error %d)." % [CONFIG_PATH, error])


func _load() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(CONFIG_PATH)  # A missing file just keeps the defaults.
	set_music_volume(config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME) if error == OK else DEFAULT_MUSIC_VOLUME)
	set_sfx_volume(config.get_value("audio", "sfx", DEFAULT_SFX_VOLUME) if error == OK else DEFAULT_SFX_VOLUME)
	set_fullscreen(config.get_value("video", "fullscreen", false) if error == OK else false)
	if error != OK:
		return
	for action: StringName in REBINDABLE:
		var physical: int = config.get_value("keys", action, KEY_NONE)
		if physical != KEY_NONE:
			rebind(action, physical as Key)


## Replaces the first key event of [param action], keeping the order of its other events.
func _set_primary(action: StringName, physical: Key) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var replaced: bool = false
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		if not replaced and event is InputEventKey:
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = physical
			event = key
			replaced = true
		InputMap.action_add_event(action, event)
	if not replaced:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = physical
		InputMap.action_add_event(action, key)


## Not in project.godot (it was a fixed key): created here so it can be rebound like the others.
func _add_models_action() -> void:
	if InputMap.has_action(InputActions.TOGGLE_MODELS):
		return
	InputMap.add_action(InputActions.TOGGLE_MODELS)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = MODELS_KEY
	InputMap.action_add_event(InputActions.TOGGLE_MODELS, key)


func _add_gamepad_events() -> void:
	for action: StringName in JOY_BUTTONS:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = JOY_BUTTONS[action]
		InputMap.action_add_event(action, button)
	for action: StringName in JOY_AXES:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = JOY_AXES[action][0]
		motion.axis_value = JOY_AXES[action][1]
		InputMap.action_add_event(action, motion)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _apply_volume(bus_name: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
