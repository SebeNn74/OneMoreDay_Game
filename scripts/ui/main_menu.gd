class_name MainMenu
extends Control
## Start screen. Logic only.

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


## Shows [param screen] (OptionsMenu, AchievementsMenu or CreditsMenu) over the menu; focus comes back to [param button].
func _open(screen: CanvasLayer, button: Button) -> void:
	_buttons.hide()  # Keeps keyboard focus inside the screen.
	screen.connect(&"closed", func() -> void:
		_buttons.show()
		button.grab_focus()
	)
	add_child(screen)
