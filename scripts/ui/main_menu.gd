class_name MainMenu
extends Control
## Start screen. Logic only.

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_play_button.pressed.connect(SceneManager.start_day)
	_quit_button.pressed.connect(get_tree().quit)
	_play_button.grab_focus()  # Enables keyboard navigation right away.
