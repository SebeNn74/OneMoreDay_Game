class_name PauseMenu
extends CanvasLayer
## Overlay shown while the game is PAUSED. Logic only.

const DRAW_LAYER: int = 90  # Below SceneTransition (100).

@onready var _content: Control = %Content
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _options_button: Button = %OptionsButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	layer = DRAW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must work while the tree is paused.
	GameManager.state_changed.connect(_on_game_state_changed)
	_resume_button.pressed.connect(GameManager.toggle_pause)
	_restart_button.pressed.connect(SceneManager.start_day)
	_options_button.pressed.connect(_open_options)
	_main_menu_button.pressed.connect(SceneManager.return_to_menu)
	# A level may load while the game is already paused (pausing during a fade).
	_set_open(GameManager.current_state == GameState.Type.PAUSED)


func _on_game_state_changed(new_state: GameState.Type, _previous_state: GameState.Type) -> void:
	_set_open(new_state == GameState.Type.PAUSED)


func _set_open(is_open: bool) -> void:
	_content.visible = is_open
	if is_open:
		_resume_button.grab_focus()


func _open_options() -> void:
	_content.hide()  # Keeps keyboard focus inside the options screen.
	var options: OptionsMenu = OptionsMenu.new()
	options.closed.connect(func() -> void:
		_set_open(GameManager.current_state == GameState.Type.PAUSED)
		if _content.visible:
			_options_button.grab_focus()
	)
	add_child(options)
