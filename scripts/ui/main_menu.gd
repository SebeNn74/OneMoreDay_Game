class_name MainMenu
extends Control
## Start screen. Logic only.

@onready var _play_button: Button = %PlayButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _buttons: Control = $CenterContainer


func _ready() -> void:
	_play_button.pressed.connect(SceneManager.start_day)
	_options_button.pressed.connect(_open_options)
	_quit_button.pressed.connect(get_tree().quit)
	_play_button.grab_focus()  # Enables keyboard navigation right away.


func _open_options() -> void:
	_buttons.hide()  # Keeps keyboard focus inside the options screen.
	var options: OptionsMenu = OptionsMenu.new()
	options.closed.connect(func() -> void:
		_buttons.show()
		_options_button.grab_focus()
	)
	add_child(options)
