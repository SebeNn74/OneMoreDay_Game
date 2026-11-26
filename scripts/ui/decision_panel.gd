class_name DecisionPanel
extends CanvasLayer
## Overlay with the options of a decision. Shows what EventBus.decision_requested asks for,
## locks the game (DIALOG state) while open, applies the picked option ONCE and closes.
## Each option is a card: its text and, below, one chip per stat it changes (icon + amount).

const DRAW_LAYER: int = 20
const NO_EFFECTS_TEXT: String = "Sin efecto"
const MINIGAME_TAG: String = "(minijuego)"
const UNAFFORDABLE_TEXT: String = "No te alcanza el dinero"
const QUEUE_LENGTH_FORMAT: String = "%d en la fila ahora"
const QUEUE_WAIT_FORMAT: String = "Wq teórico %.1f"
const WAITED_FORMAT: String = "Esperaste %d de tiempo en la fila."
const NO_WAIT_TEXT: String = "La fila andaba vacía: pasaste sin esperar."
const HINT_TEXT: String = "[{up}/{down}] Elegir   [{interact}] Confirmar"
## Model 3 on the card: chance, what goes wrong and what it costs.
const RISK_FORMAT: String = "Riesgo %d %%: %s (%s)"
## Bonus by state: stat name, threshold, why and what it gives.
const BONUS_FORMAT: String = "Si tu %s está bajo %s: %s (%s)"
## After choosing: the draw of the LCG against the chance.
const RISK_HIT_FORMAT: String = "Monte Carlo: salió %.2f < %.2f. Mala suerte: %s (%s)."
const RISK_MISS_FORMAT: String = "Monte Carlo: salió %.2f >= %.2f. Te salvaste: no %s."
const BONUS_GIVEN_FORMAT: String = "%s (%s)."
## Order of the chips under an option.
const STAT_ORDER: Array[StatDefinition.Type] = [
	StatDefinition.Type.MONEY, StatDefinition.Type.ENERGY, StatDefinition.Type.TIME,
]

const GAIN_COLOR: Color = Color(0.45, 0.85, 0.45)
const LOSS_COLOR: Color = Color(0.95, 0.45, 0.40)
const NEUTRAL_COLOR: Color = Color(0.75, 0.75, 0.75)
const ACCENT_COLOR: Color = Color(1.0, 0.9, 0.4)
const CARD_COLOR: Color = Color(1.0, 1.0, 1.0, 0.06)
const CARD_SELECTED_COLOR: Color = Color(1.0, 0.9, 0.4, 0.16)
const DISABLED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.45)
const ICON_SIZE: Vector2 = Vector2(16.0, 16.0)
const CHIP_SEPARATION: int = 3
const CHIPS_SEPARATION: int = 12
const CARD_SEPARATION: int = 2
const EFFECTS_FONT_SIZE: int = 14

@onready var _content: Control = %Content
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _options_box: VBoxContainer = %OptionsBox
@onready var _hint_label: Label = $Content/CenterContainer/Panel/Padding/VBox/HintLabel

var _decision: DecisionDefinition
var _cards: Array[PanelContainer] = []
var _enabled: Array[bool] = []
var _selected: int = 0
var _opened_frame: int = -1
var _is_resolved: bool = true
## Lines drawn for queues that have no QueueCrowd on the map (see _people_in).
var _drawn_lines: Dictionary = {}
var _card_style: StyleBoxFlat = _make_card_style(CARD_COLOR, Color.TRANSPARENT)
var _selected_style: StyleBoxFlat = _make_card_style(CARD_SELECTED_COLOR, ACCENT_COLOR)


func _ready() -> void:
	layer = DRAW_LAYER
	$Content/CenterContainer/Panel.add_theme_stylebox_override("panel", StatFormatter.panel_style())
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
	_hint_label.text = Settings.with_keys(HINT_TEXT)
	_build_cards()
	_select(_first_available_index())
	_content.visible = true
	_opened_frame = Engine.get_process_frames()
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)


func _build_cards() -> void:
	for old_card: PanelContainer in _cards:
		_options_box.remove_child(old_card)
		old_card.queue_free()
	_cards.clear()
	_enabled.clear()

	for index: int in _decision.options.size():
		var option: DecisionOption = _decision.options[index]
		var is_affordable: bool = _is_affordable(option)
		var card: PanelContainer = _build_card(option, is_affordable)
		card.mouse_entered.connect(_select.bind(index))
		card.gui_input.connect(_on_card_input.bind(index))
		_options_box.add_child(card)
		_cards.append(card)
		_enabled.append(is_affordable)

	# Safety net against a soft lock: never leave the player with no option to pick.
	if not _enabled.has(true):
		push_warning("DecisionPanel: no affordable option in '%s'. Enabling all of them." % _decision.id)
		_enabled.fill(true)
	for index: int in _cards.size():
		_cards[index].modulate = Color.WHITE if _enabled[index] else DISABLED_MODULATE


func _build_card(option: DecisionOption, is_affordable: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", CARD_SEPARATION)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var title: Label = Label.new()
	title.text = option.text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if option.minigame == null:
		box.add_child(title)
	else:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		var tag: Label = Label.new()
		tag.text = MINIGAME_TAG
		tag.add_theme_color_override("font_color", ACCENT_COLOR)
		tag.add_theme_font_size_override("font_size", EFFECTS_FONT_SIZE)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		box.add_child(row)

	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", CHIPS_SEPARATION)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chips)
	if not is_affordable:
		chips.add_child(_make_chip(StatsManager.get_definition(StatDefinition.Type.MONEY).icon, UNAFFORDABLE_TEXT, LOSS_COLOR))
		return card
	_add_effect_chips(chips, option)
	if option.queue != null:
		_add_queue_chips(chips, option.queue)
	if chips.get_child_count() == 0:
		chips.add_child(_make_chip(null, NO_EFFECTS_TEXT, NEUTRAL_COLOR))
	if option.has_risk():
		box.add_child(_make_note(RISK_FORMAT % [
			roundi(option.risk_chance * 100.0), option.risk_text,
			StatFormatter.describe_changes(option.risk_money, option.risk_energy, option.risk_time)], LOSS_COLOR))
	if option.has_bonus():
		var definition: StatDefinition = StatsManager.get_definition(option.bonus_stat)
		box.add_child(_make_note(BONUS_FORMAT % [
			definition.display_name.to_lower(), StatFormatter.format_value(option.bonus_stat, option.bonus_below),
			option.bonus_text, StatFormatter.describe_changes(option.bonus_money, option.bonus_energy, option.bonus_time)],
			GAIN_COLOR if _bonus_applies(option) else NEUTRAL_COLOR))
	return card


func _make_note(text: String, color: Color) -> Label:
	var note: Label = Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", color)
	note.add_theme_font_size_override("font_size", EFFECTS_FONT_SIZE - 2)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return note


## One chip per stat the option changes, in STAT_ORDER.
func _add_effect_chips(chips: HBoxContainer, option: DecisionOption) -> void:
	var effects: Dictionary = {
		StatDefinition.Type.MONEY: option.money,
		StatDefinition.Type.ENERGY: option.energy,
		StatDefinition.Type.TIME: option.time,
	}
	for type: StatDefinition.Type in STAT_ORDER:
		var amount: float = effects[type]
		if is_zero_approx(amount):
			continue
		chips.add_child(_make_chip(
			StatsManager.get_definition(type).icon,
			StatFormatter.format_change(type, amount),
			GAIN_COLOR if amount > 0.0 else LOSS_COLOR,
		))


## Model 1: a queue option shows the theoretical wait and how many people are in that line now
## (the same line QueueScreen starts with). The real wait is only known once in line.
func _add_queue_chips(chips: HBoxContainer, queue: QueueConfig) -> void:
	chips.add_child(_make_chip(
		StatsManager.get_definition(StatDefinition.Type.TIME).icon,
		QUEUE_WAIT_FORMAT % QueueModel.mean_wait(queue),
		LOSS_COLOR,
	))
	chips.add_child(_make_chip(null, QUEUE_LENGTH_FORMAT % _people_in(queue), NEUTRAL_COLOR))


## People in the line of [param queue]: the one on the map, or a draw from P(n) = (1 - ρ) ρ^n
## (remembered, so the panel and the queue screen agree) when the level has no line on the map.
func _people_in(queue: QueueConfig) -> int:
	var crowd: QueueCrowd = _live_queue(queue)
	if crowd != null:
		return crowd.people_in_line()
	if not _drawn_lines.has(queue):
		var rho: float = QueueModel.utilization(queue)
		var people: int = 0
		while Simulation.rng.next() < rho and people < QueueCrowd.MAX_PEOPLE - 1:
			people += 1
		_drawn_lines[queue] = people
	return _drawn_lines[queue]


## The QueueCrowd of the current level that simulates [param queue], if any.
func _live_queue(queue: QueueConfig) -> QueueCrowd:
	for node: Node in get_tree().get_nodes_in_group(QueueCrowd.GROUP):
		var crowd: QueueCrowd = node as QueueCrowd
		if crowd != null and crowd.queue == queue:
			return crowd
	return null


func _make_chip(icon: Texture2D, text: String, color: Color) -> HBoxContainer:
	var chip: HBoxContainer = HBoxContainer.new()
	chip.add_theme_constant_override("separation", CHIP_SEPARATION)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = ICON_SIZE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon_rect)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", EFFECTS_FONT_SIZE)
	chip.add_child(label)
	return chip


static func _make_card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


## Money is a payment: an option that would leave it depleted cannot be paid, counting the worst
## case of its risk (a haggle that goes wrong must not bankrupt the player at the door).
## Energy and time costs are a risk the player may take, so they never disable an option.
func _is_affordable(option: DecisionOption) -> bool:
	var worst_risk: float = minf(option.risk_money, 0.0) if option.has_risk() else 0.0
	return StatsManager.can_afford(StatDefinition.Type.MONEY, option.money + worst_risk)


## Model 1: the player waits in the option's queue. Returns the message that tells how long
func _apply_queue_wait(option: DecisionOption) -> String:
	if option.queue == null:
		return ""
	var wait: float = Simulation.queue_wait(option.queue)
	if roundi(wait) == 0:
		return NO_WAIT_TEXT
	return WAITED_FORMAT % roundi(wait)


func _on_card_input(event: InputEvent, index: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_choose(index)


func _first_available_index() -> int:
	var index: int = _enabled.find(true)
	return maxi(index, 0)


func _select(index: int) -> void:
	if not _enabled[index]:
		return
	_selected = index
	for card_index: int in _cards.size():
		_cards[card_index].add_theme_stylebox_override(
			"panel", _selected_style if card_index == index else _card_style)


func _move_selection(step: int) -> void:
	var count: int = _cards.size()
	for offset: int in range(1, count):
		var index: int = posmod(_selected + step * offset, count)
		if _enabled[index]:
			_select(index)
			AudioManager.play_sfx(&"ui_move")
			return


func _choose(index: int) -> void:
	if _is_resolved or not _enabled[index]:
		return
	_is_resolved = true
	var option: DecisionOption = _decision.options[index]
	var bonus_given: bool = _bonus_applies(option)  # Judged before the option changes the stat.
	Simulation.apply_change(option.money, option.energy, option.time)
	var outcome: String = _apply_bonus_and_risk(option, bonus_given)
	if not outcome.is_empty():
		EventBus.toast_requested.emit(outcome)
	if option.queue != null:
		# Model 1: the player joins the line in QueueScreen, with the people shown in the panel.
		var decision: DecisionDefinition = _decision
		var crowd: QueueCrowd = _live_queue(option.queue)
		var ahead: int = _people_in(option.queue)
		_drawn_lines.erase(option.queue)
		_close()
		var screen: QueueScreen = QueueScreen.open(get_tree().current_scene, option.queue, ahead)
		await screen.finished
		if crowd != null:
			crowd.set_people(screen.people_left())
		EventBus.decision_resolved.emit(decision, option)
		return
	var wait_message: String = _apply_queue_wait(option)
	EventBus.decision_resolved.emit(_decision, option)
	_close()
	if (not wait_message.is_empty() and GameManager.current_state == GameState.Type.PLAYING
			and not SceneManager.is_transitioning() and option.next_scene.is_empty()):
		EventBus.notification_requested.emit(wait_message)


func _bonus_applies(option: DecisionOption) -> bool:
	return option.has_bonus() and StatsManager.get_value(option.bonus_stat) < option.bonus_below


## Bonus by state, then model 3: one LCG draw against risk_chance decides the bad outcome.
## Returns the message that tells the player what happened ("" when the option has neither).
func _apply_bonus_and_risk(option: DecisionOption, bonus_given: bool) -> String:
	var lines: PackedStringArray = []
	if bonus_given:
		Simulation.apply_change(option.bonus_money, option.bonus_energy, option.bonus_time)
		lines.append(BONUS_GIVEN_FORMAT % [option.bonus_text.left(1).to_upper() + option.bonus_text.substr(1),
			StatFormatter.describe_changes(option.bonus_money, option.bonus_energy, option.bonus_time)])
	if option.has_risk():
		var draw: float = Simulation.rng.next()
		var happened: bool = draw < option.risk_chance
		if happened:
			Simulation.apply_change(option.risk_money, option.risk_energy, option.risk_time)
			lines.append(RISK_HIT_FORMAT % [draw, option.risk_chance, option.risk_text,
				StatFormatter.describe_changes(option.risk_money, option.risk_energy, option.risk_time)])
		else:
			lines.append(RISK_MISS_FORMAT % [draw, option.risk_chance, option.risk_text])
		Simulation.report(Simulation.MODEL_MONTE_CARLO, "Riesgo '%s': U = %.2f %s p = %.2f -> %s" % [
			option.text, draw, "<" if happened else ">=", option.risk_chance, "pasa" if happened else "no pasa"])
		EventBus.risk_drawn.emit(option, happened, draw)
	return "\n".join(lines)


func _close() -> void:
	_content.visible = false
	if GameManager.current_state == GameState.Type.DIALOG:
		GameManager.change_state(GameState.Type.PLAYING)
