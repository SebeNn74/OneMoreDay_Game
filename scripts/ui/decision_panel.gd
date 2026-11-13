class_name DecisionPanel
extends CanvasLayer
## Overlay with the options of a decision. Shows what EventBus.decision_requested asks for,
## locks the game (DIALOG state) while open, applies the picked option ONCE and closes.

const DRAW_LAYER: int = 20
const SELECTED_MODULATE: Color = Color(1.0, 0.9, 0.4)
const UNSELECTED_MODULATE: Color = Color.WHITE
const EFFECT_SEPARATOR: String = "   "
## Player-visible texts (Spanish).
const NO_EFFECTS_TEXT: String = "Sin efecto"
const UNAFFORDABLE_TEXT: String = "No te alcanza el dinero"

@onready var _content: Control = %Content
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _options_box: VBoxContainer = %OptionsBox

var _decision: DecisionDefinition
var _buttons: Array[Button] = []
var _selected: int = 0
var _opened_frame: int = -1
var _is_resolved: bool = true


func _ready() -> void:
	layer = DRAW_LAYER
	_content.visible = false
	EventBus.decision_requested.connect(_on_decision_requested)


func _unhandled_input(event: InputEvent) -> void:
	if not _content.visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(InputActions.MOVE_DOWN):
		_move_selection(1)
	elif event.is_action_pressed(InputActions.MOVE_UP):
		_move_selection(-1)
	elif event.is_action_pressed(InputActions.INTERACT):
		_choose(_selected)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_decision_requested(decision: DecisionDefinition) -> void:
	assert(not decision.options.is_empty(), "DecisionPanel: '%s' has no options." % decision.id)
	_decision = decision
	_is_resolved = false
	_speaker_label.text = decision.speaker_name
	_prompt_label.text = decision.prompt
	_build_buttons()
	_select(_first_available_index())
	_content.visible = true
	_opened_frame = Engine.get_process_frames()
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)


func _build_buttons() -> void:
	for old_button: Button in _buttons:
		_options_box.remove_child(old_button)
		old_button.queue_free()
	_buttons.clear()

	for index: int in _decision.options.size():
		var option: DecisionOption = _decision.options[index]
		var is_affordable: bool = _is_affordable(option)
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not is_affordable
		button.text = "%s\n%s" % [option.text, _describe_effects(option) if is_affordable else UNAFFORDABLE_TEXT]
		button.pressed.connect(_choose.bind(index))
		button.mouse_entered.connect(_select.bind(index))
		_options_box.add_child(button)
		_buttons.append(button)

	# Safety net against a soft lock: never leave the player with no option to pick.
	if _buttons.all(func(button: Button) -> bool: return button.disabled):
		push_warning("DecisionPanel: no affordable option in '%s'. Enabling all of them." % _decision.id)
		for button: Button in _buttons:
			button.disabled = false


## Money is a payment: an option that would leave it depleted cannot be paid.
## Energy and time costs are a risk the player may take, so they never disable an option.
func _is_affordable(option: DecisionOption) -> bool:
	if option.money >= 0.0:
		return true
	var money_after: float = StatsManager.get_value(StatDefinition.Type.MONEY) + option.money
	return not StatsManager.get_definition(StatDefinition.Type.MONEY).is_depleted_at(money_after)


func _describe_effects(option: DecisionOption) -> String:
	var effects: Dictionary = {
		StatDefinition.Type.MONEY: option.money,
		StatDefinition.Type.ENERGY: option.energy,
		StatDefinition.Type.TIME: option.time,
	}
	var parts: PackedStringArray = []
	for type: StatDefinition.Type in effects:
		var amount: float = effects[type]
		if is_zero_approx(amount):
			continue
		var stat_name: String = StatsManager.get_definition(type).display_name
		parts.append("%s %s" % [stat_name, StatFormatter.format_change(type, amount)])
	if parts.is_empty():
		return NO_EFFECTS_TEXT
	return EFFECT_SEPARATOR.join(parts)


func _first_available_index() -> int:
	for index: int in _buttons.size():
		if not _buttons[index].disabled:
			return index
	return 0


func _select(index: int) -> void:
	if _buttons[index].disabled:
		return
	_selected = index
	for button_index: int in _buttons.size():
		_buttons[button_index].modulate = SELECTED_MODULATE if button_index == index else UNSELECTED_MODULATE


func _move_selection(step: int) -> void:
	var count: int = _buttons.size()
	for offset: int in range(1, count):
		var index: int = posmod(_selected + step * offset, count)
		if not _buttons[index].disabled:
			_select(index)
			return


func _choose(index: int) -> void:
	if _is_resolved or _buttons[index].disabled:
		return
	_is_resolved = true
	var option: DecisionOption = _decision.options[index]
	Simulation.apply_change(option.money, option.energy, option.time)
	EventBus.decision_resolved.emit(_decision, option)
	_close()


func _close() -> void:
	_content.visible = false
	if GameManager.current_state == GameState.Type.DIALOG:
		GameManager.change_state(GameState.Type.PLAYING)
