class_name LevelGuide
extends CanvasLayer
## Tells the player what to do:
##  - the first time a day starts in this session, a "Cómo jugar" card (game locked in DIALOG);
##  - on every level, a banner with the stage and BaseLevel.objective;
##  - an arrow to BaseLevel.get_guide_target(): above it when on screen, at the screen edge when not.

const DRAW_LAYER: int = 16  # Above the HUD and the model panel, below dialogs (20).
const STAGE_NAMES: Dictionary = {
	DayStep.Stage.HOME: "Casa",
	DayStep.Stage.COMMUTE: "Ida al trabajo",
	DayStep.Stage.WORK: "Jornada",
	DayStep.Stage.RETURN: "Vuelta a casa",
}
const STAGE_FORMAT: String = "%s · %d de %d"
const LEVELS_PER_STAGE: int = 3
const BANNER_TOP: float = 112.0
const BANNER_WIDTH: float = 340.0
const BANNER_SECONDS: float = 4.0
const BANNER_FADE_SECONDS: float = 0.8
const ARROW_COLOR: Color = Color(1.0, 0.85, 0.3)
const ARROW_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.8)
const ARROW_SIZE: float = 9.0
const EDGE_MARGIN: float = 18.0
## Above the target when it is on screen, bobbing.
const ARROW_LIFT: float = 44.0
const BOB_PIXELS: float = 3.0
const BOB_SPEED: float = 5.0
const CARD_WIDTH: float = 460.0
const CARD_TITLE: String = "Un día más"
const CARD_GOAL: String = "Llega a casa al final del día sin que se te acabe ningún recurso:"
const CARD_STATS: Dictionary = {
	StatDefinition.Type.MONEY: "pasajes, comida e imprevistos. Algunos te lo roban.",
	StatDefinition.Type.ENERGY: "caminar y correr la gastan; sentarte la recupera. Bajo 30 caminas más lento.",
	StatDefinition.Type.TIME: "corre siempre. Golpes, filas y eventos te quitan más.",
}
const CARD_TIPS: PackedStringArray = [
	"Carros y motos cruzan rápido: mira antes de cruzar. Algunos hostiles te persiguen: corre con {run}.",
	"Habla con la gente y recoge objetos con [{interact}]. Cada decisión cuesta o da recursos.",
	"La plata cuenta: si llegas con más de lo que tenías, o te das un gusto en el camino, el final cambia.",
	"La flecha amarilla te lleva al objetivo. [{models}] muestra u oculta los modelos de simulación. Teclas y volumen: Opciones, en la pausa ([{pause}]).",
]
## {interact}, {run}... are replaced with the current keys (Settings.with_keys).
const CARD_HINT: String = "[{interact}] Empezar el día"
const SMALL_FONT: int = 12

## The card is shown once per game session.
static var card_seen: bool = false

var _level: BaseLevel
var _arrow_canvas: Control
var _banner: PanelContainer
var _card: Control
var _time: float = 0.0


func _ready() -> void:
	layer = DRAW_LAYER
	_level = owner as BaseLevel
	_arrow_canvas = Control.new()
	_arrow_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_canvas.draw.connect(_draw_arrow)
	add_child(_arrow_canvas)
	if SceneManager.is_transitioning():
		# The level loads behind the fade: anything that locks the game must wait for it.
		EventBus.day_step_started.connect(_start.unbind(1), CONNECT_ONE_SHOT)
	else:
		_start.call_deferred()


func _start() -> void:
	var step: DayStep = SceneManager.get_current_step()
	if step != null and step.stage == DayStep.Stage.HOME and not card_seen:
		card_seen = true
		_show_card()
	else:
		_show_banner()


func _process(delta: float) -> void:
	_time += delta
	_arrow_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _card != null and event.is_action_pressed(InputActions.INTERACT):
		get_viewport().set_input_as_handled()
		_card.queue_free()
		_card = null
		if GameManager.current_state == GameState.Type.DIALOG:
			GameManager.change_state(GameState.Type.PLAYING)
		_show_banner()


func _show_banner() -> void:
	if _level == null:
		return
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", _panel_style(0.7))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.custom_minimum_size.x = BANNER_WIDTH  # Autowrapped labels need a width to wrap at.
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_banner.add_child(box)
	var step: DayStep = SceneManager.get_current_step()
	if step != null:
		var stage_text: String = STAGE_NAMES[step.stage]
		if step.stage != DayStep.Stage.HOME:
			stage_text = STAGE_FORMAT % [stage_text, step.number_in_stage, LEVELS_PER_STAGE]
		box.add_child(_label(stage_text, ARROW_COLOR, SMALL_FONT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(_level.objective, Color.WHITE, 0, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_banner)
	# Center once the container knows its size.
	await get_tree().process_frame
	if not is_instance_valid(_banner):
		return
	_banner.position = Vector2((BaseLevel.SCREEN_SIZE.x - _banner.size.x) / 2.0, BANNER_TOP)
	var tween: Tween = create_tween()
	tween.tween_interval(BANNER_SECONDS)
	tween.tween_property(_banner, "modulate:a", 0.0, BANNER_FADE_SECONDS)
	tween.tween_callback(_banner.queue_free)


func _show_card() -> void:
	if GameManager.current_state == GameState.Type.PLAYING:
		GameManager.change_state(GameState.Type.DIALOG)
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.92))
	panel.custom_minimum_size.x = CARD_WIDTH
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label(CARD_TITLE, ARROW_COLOR, 0, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(CARD_GOAL, Color.WHITE, SMALL_FONT))
	for type: StatDefinition.Type in CARD_STATS:
		var definition: StatDefinition = StatsManager.get_definition(type)
		var row: HBoxContainer = HBoxContainer.new()
		var icon: TextureRect = TextureRect.new()
		icon.texture = definition.icon
		icon.custom_minimum_size = Vector2(16.0, 16.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var text: Label = _label("%s: %s" % [definition.display_name, CARD_STATS[type]], Color.WHITE, SMALL_FONT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		box.add_child(row)
	box.add_child(HSeparator.new())
	for tip: String in CARD_TIPS:
		box.add_child(_label("• " + Settings.with_keys(tip), Color(0.85, 0.85, 0.85), SMALL_FONT))
	box.add_child(_label(Settings.with_keys(CARD_HINT), ARROW_COLOR, SMALL_FONT, HORIZONTAL_ALIGNMENT_RIGHT))
	add_child(_card)


func _label(text: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _panel_style(alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, alpha)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8.0)
	return style


func _draw_arrow() -> void:
	if _level == null or _card != null or GameManager.current_state != GameState.Type.PLAYING:
		return
	var target: Variant = _level.get_guide_target()
	if target == null:
		return
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(BaseLevel.SCREEN_SIZE))
	var point: Vector2 = _level.get_viewport().get_canvas_transform() * (target as Vector2)
	var inner: Rect2 = screen.grow(-EDGE_MARGIN)
	if inner.has_point(point):
		var tip: Vector2 = point + Vector2(0.0, -ARROW_LIFT + sin(_time * BOB_SPEED) * BOB_PIXELS)
		_draw_triangle(tip, Vector2.DOWN)
		return
	# Off screen: on the edge, pointing at it from the screen center.
	var center: Vector2 = screen.get_center()
	var direction: Vector2 = (point - center).normalized()
	var half: Vector2 = inner.size / 2.0
	var scale_to_edge: float = minf(
		half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	_draw_triangle(center + direction * scale_to_edge, direction)


func _draw_triangle(tip: Vector2, direction: Vector2) -> void:
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var base: Vector2 = tip - direction * ARROW_SIZE * 1.6
	var points: PackedVector2Array = [tip, base + side * ARROW_SIZE, base - side * ARROW_SIZE]
	_arrow_canvas.draw_colored_polygon(points, ARROW_COLOR)
	points.append(tip)
	_arrow_canvas.draw_polyline(points, ARROW_OUTLINE, 1.5)
