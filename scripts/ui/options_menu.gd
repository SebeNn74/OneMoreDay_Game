class_name OptionsMenu
extends CanvasLayer
## Options screen, opened from the main menu and the pause menu: music and effects volume,
## fullscreen and key bindings. Built in code; the values live in the Settings autoload, which saves
## them when the screen closes. Esc (or the pause key) closes it.

signal closed

const DRAW_LAYER: int = 95  # Above PauseMenu (90), below SceneTransition (100).
const PANEL_WIDTH: float = 430.0
const SMALL_FONT: int = 12
const PERCENT_STEP: float = 5.0
const ACCENT: Color = Color(1.0, 0.85, 0.3)
const MUTED: Color = Color(0.75, 0.75, 0.75)
## Player-visible texts (Spanish).
const TITLE: String = "OPCIONES"
const MUSIC_LABEL: String = "Música"
const SFX_LABEL: String = "Efectos"
const FULLSCREEN_LABEL: String = "Pantalla completa (F11)"
const CONTROLS_TITLE: String = "CONTROLES  (clic en una tecla para cambiarla)"
const WAITING_TEXT: String = "Pulsa una tecla..."
const FIXED_KEYS_TEXT: String = "También funcionan las flechas, Espacio, P y el mando (cruceta o stick, A, RB, Start). [M] panel de modelos."
const RESET_TEXT: String = "RESTAURAR TECLAS"
const BACK_TEXT: String = "VOLVER"

var _key_buttons: Dictionary = {}  # action -> Button
var _waiting_action: StringName = &""
var _back_button: Button


func _ready() -> void:
	layer = DRAW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS  # Opened from the pause menu, with the tree paused.
	_build()
	_back_button.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if not _waiting_action.is_empty():
		var key: InputEventKey = event as InputEventKey
		if key != null and key.pressed and not key.echo:
			# Esc cancels, unless the key being changed is the pause key itself.
			if key.physical_keycode != KEY_ESCAPE or _waiting_action == InputActions.PAUSE:
				Settings.rebind(_waiting_action, key.physical_keycode)
			_waiting_action = &""
			_refresh_keys()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Settings.save()
	closed.emit()
	queue_free()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.95)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	box.add_child(_label(TITLE, ACCENT, 0, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_slider_row(MUSIC_LABEL, Settings.music_volume, Settings.set_music_volume, false))
	box.add_child(_slider_row(SFX_LABEL, Settings.sfx_volume, Settings.set_sfx_volume, true))
	var fullscreen: CheckButton = CheckButton.new()
	fullscreen.text = FULLSCREEN_LABEL
	fullscreen.add_theme_font_size_override("font_size", SMALL_FONT)
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(Settings.set_fullscreen)
	box.add_child(fullscreen)

	box.add_child(HSeparator.new())
	box.add_child(_label(CONTROLS_TITLE, ACCENT, SMALL_FONT))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	for action: StringName in Settings.REBINDABLE:
		var name_label: Label = _label(Settings.ACTION_NAMES[action], Color.WHITE, SMALL_FONT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(96.0, 18.0)
		button.add_theme_font_size_override("font_size", SMALL_FONT)
		button.pressed.connect(_start_rebind.bind(action))
		grid.add_child(button)
		_key_buttons[action] = button
	box.add_child(grid)
	var fixed_keys: Label = _label(FIXED_KEYS_TEXT, MUTED, SMALL_FONT)
	fixed_keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(fixed_keys)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var reset: Button = Button.new()
	reset.text = RESET_TEXT
	reset.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset)
	_back_button = Button.new()
	_back_button.text = BACK_TEXT
	_back_button.custom_minimum_size.x = 100.0
	_back_button.pressed.connect(_close)
	buttons.add_child(_back_button)
	box.add_child(buttons)
	_refresh_keys()


func _slider_row(text: String, value: float, setter: Callable, is_sfx: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = _label(text, Color.WHITE, SMALL_FONT)
	name_label.custom_minimum_size.x = 70.0
	row.add_child(name_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = PERCENT_STEP
	slider.value = roundf(value * 100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var percent: Label = _label("%d %%" % roundi(slider.value), MUTED, SMALL_FONT)
	percent.custom_minimum_size.x = 40.0
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)
	slider.value_changed.connect(func(new_value: float) -> void:
		setter.call(new_value / 100.0)
		percent.text = "%d %%" % roundi(new_value)
		if is_sfx:
			AudioManager.play_sfx(&"coin")  # Hear the new effects volume.
	)
	return row


func _start_rebind(action: StringName) -> void:
	_waiting_action = action
	_refresh_keys()


func _on_reset_pressed() -> void:
	_waiting_action = &""
	Settings.reset_bindings()
	_refresh_keys()


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		var button: Button = _key_buttons[action]
		button.text = WAITING_TEXT if action == _waiting_action else Settings.key_name(action)


func _label(text: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_color_override("font_color", color)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
