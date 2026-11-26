class_name MainMenu
extends Control
## Start screen. Logic only.

## Arrows move the focus (ui_up/ui_down); Enter (ui_accept) and the interact key press the button.
const HINT_TEXT: String = "[Flechas] Elegir   [Enter] o [{interact}] Seleccionar"
const HINT_COLOR: Color = Color(0.75, 0.75, 0.8)
const HINT_FONT_SIZE: int = 12

var _hint_label: Label = Label.new()

@onready var _play_button: Button = %PlayButton
@onready var _options_button: Button = %OptionsButton
@onready var _achievements_button: Button = %AchievementsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _buttons: Control = $CenterContainer


func _ready() -> void:
	_play_button.pressed.connect(SceneManager.start_day)
	_options_button.pressed.connect(func() -> void: _open(OptionsMenu.new(), _options_button))
	_achievements_button.pressed.connect(func() -> void: _open(AchievementsMenu.new(), _achievements_button))
	_credits_button.pressed.connect(func() -> void: _open(CreditsMenu.new(), _credits_button))
	_quit_button.pressed.connect(get_tree().quit)
	_play_button.grab_focus()  # Enables keyboard navigation right away.
	_hint_label.text = Settings.with_keys(HINT_TEXT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	_hint_label.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)  # Readable over the busy background.
	_hint_label.add_theme_constant_override("outline_size", 4)
	_quit_button.get_parent().add_child(_hint_label)


## Enter already presses the focused button (ui_accept); the interact key (E) does it too.
func _unhandled_input(event: InputEvent) -> void:
	if not _buttons.visible or not event.is_action_pressed(InputActions.INTERACT):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and _buttons.is_ancestor_of(focused):
		get_viewport().set_input_as_handled()
		(focused as Button).pressed.emit()


## Shows [param screen] (OptionsMenu, AchievementsMenu or CreditsMenu) over the menu; focus comes back to [param button].
func _open(screen: CanvasLayer, button: Button) -> void:
	_buttons.hide()  # Keeps keyboard focus inside the screen.
	screen.connect(&"closed", func() -> void:
		_buttons.show()
		_hint_label.text = Settings.with_keys(HINT_TEXT)  # The interact key may have been rebound.
		button.grab_focus()
	)
	add_child(screen)
