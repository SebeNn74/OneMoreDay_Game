class_name EmpanadaCatchMinigame
extends Minigame
## "Atrapa las empanadas": the vendor tosses empanadas (Poisson arrivals, λ = TOSS_RATE) that fall
## from random spots; move with A/D to catch them. Each one caught gives a bit more energy.

const NPC_FRAMES: SpriteFrames = preload("res://assets/sprites/npcs/npc_sprite_frames.tres")
const ITEM_FRAMES: SpriteFrames = preload("res://assets/sprites/items/items_sprite_frames.tres")
const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_sprite_frames.tres")
const TOSS_RATE: float = 1.6
const GRAVITY: float = 260.0
const PLAYER_SPEED: float = 280.0
const PLAYER_Y: float = 320.0
const CATCH_RADIUS: float = 22.0
const MIN_X: float = 60.0
const MAX_X: float = 580.0
const ENERGY_PER_CATCH: float = 1.5
const MAX_CATCHES_PAID: int = 8

var _player: AnimatedSprite2D
var _vendor: AnimatedSprite2D
var _falling: Array[Dictionary] = []  # {sprite, speed}
var _next_toss: float = 0.5
var _tossed: int = 0
var _caught: int = 0
var _canvas: Control
var _food: Node2D
var _rng: Lcg


func _init() -> void:
	title = "Atrapa las empanadas"
	instructions = "El vendedor te lanza las empanadas calientes. Muévete con A y D para atraparlas antes de que caigan al piso. Cada una que atrapes te da un poco más de energía."
	duration_seconds = 12.0


func _build(stage: Control) -> void:
	_rng = Simulation.rng
	_canvas = Control.new()
	_canvas.size = SCREEN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	stage.add_child(_canvas)
	var people: Node2D = Node2D.new()
	stage.add_child(people)
	_vendor = _sprite(NPC_FRAMES, &"empanada_vendor", Vector2(320.0, 118.0), 80.0)
	people.add_child(_vendor)
	_food = Node2D.new()
	stage.add_child(_food)
	_player = _sprite(PLAYER_FRAMES, &"idle_up", Vector2(320.0, PLAYER_Y), 72.0)
	people.add_child(_player)


func _play(delta: float) -> void:
	var input: float = Input.get_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT)
	_player.position.x = clampf(_player.position.x + input * PLAYER_SPEED * delta, MIN_X, MAX_X)
	_vendor.position.x = 320.0 + sin(_phase_time * 1.7) * 160.0

	_next_toss -= delta
	if _next_toss <= 0.0 and _time_left > 1.2:
		_toss()
		_next_toss = _rng.exponential(TOSS_RATE)

	var hands: Vector2 = _player.position + Vector2(0.0, -48.0)
	for i: int in range(_falling.size() - 1, -1, -1):
		var item: Dictionary = _falling[i]
		var sprite: AnimatedSprite2D = item.sprite
		item.speed += GRAVITY * delta
		sprite.position += Vector2(item.drift, item.speed) * delta
		sprite.rotation += delta * 4.0
		if sprite.position.distance_to(hands) < CATCH_RADIUS:
			_caught += 1
			AudioManager.play_sfx(&"pickup", 1.0 + _caught * 0.05)
			sprite.queue_free()
			_falling.remove_at(i)
		elif sprite.position.y > SCREEN.y + 20.0:
			sprite.queue_free()
			_falling.remove_at(i)
	_canvas.queue_redraw()


func _toss() -> void:
	var sprite: AnimatedSprite2D = _sprite(ITEM_FRAMES, &"empanada", _vendor.position + Vector2(0.0, -40.0), 26.0)
	sprite.offset = Vector2.ZERO
	_food.add_child(sprite)
	var target_x: float = MIN_X + _rng.next() * (MAX_X - MIN_X)
	var fall_time: float = 1.6
	_falling.append({"sprite": sprite, "speed": -60.0, "drift": (target_x - sprite.position.x) / fall_time})
	_tossed += 1


func _result() -> Dictionary:
	Simulation.report(Simulation.MODEL_MONTE_CARLO, "Empanadas: %d lanzadas (Poisson, λ = %.1f/s), %d atrapadas" % [
		_tossed, TOSS_RATE, _caught])
	var paid: int = mini(_caught, MAX_CATCHES_PAID)
	var summary: String = "Atrapaste %d de %d empanadas" % [_caught, _tossed]
	return {"money": 0.0, "energy": ENERGY_PER_CATCH * paid, "time": 0.0, "summary": summary}


func _draw_scene() -> void:
	var c: Control = _canvas
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("b8b0a0"))  # Sidewalk.
	c.draw_rect(Rect2(0.0, 0.0, SCREEN.x, 60.0), Color("e8a85c"))  # Shop fronts.
	c.draw_rect(Rect2(200.0, 120.0, 240.0, 30.0), Color("d35400"))  # Stand.
	c.draw_rect(Rect2(200.0, 116.0, 240.0, 6.0), Color("f39c12"))
	for x: float in range(0, int(SCREEN.x), 64):
		c.draw_line(Vector2(x, 200.0), Vector2(x, SCREEN.y), Color(0.0, 0.0, 0.0, 0.08))
	if is_playing():
		c.draw_string(c.get_theme_default_font(), Vector2(20.0, 340.0), "Atrapadas: %d" % _caught, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
