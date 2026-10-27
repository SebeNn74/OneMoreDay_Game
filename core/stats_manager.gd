extends Node
## Autoload. Owns the runtime Stat instances and announces every change via EventBus.
## Every system that wants to change a stat must go through modify().

const MONEY_DEFINITION: StatDefinition = preload("res://data/stats/money.tres")
const ENERGY_DEFINITION: StatDefinition = preload("res://data/stats/energy.tres")
const TIME_DEFINITION: StatDefinition = preload("res://data/stats/time.tres")

# Maps StatDefinition.Type -> Stat.
var _stats: Dictionary = {}


func _ready() -> void:
	for definition: StatDefinition in [MONEY_DEFINITION, ENERGY_DEFINITION, TIME_DEFINITION]:
		_stats[definition.type] = Stat.new(definition)
	reset_all()


## Adds [param amount] (negative to subtract) to a stat.
func modify(type: StatDefinition.Type, amount: float) -> void:
	var stat: Stat = _get_stat(type)
	var was_depleted: bool = stat.is_depleted()
	var applied_change: float = stat.modify(amount)

	if is_zero_approx(applied_change):
		return

	EventBus.stat_changed.emit(type, stat.value, applied_change)
	if stat.is_depleted() and not was_depleted:
		EventBus.stat_depleted.emit(type)


func get_value(type: StatDefinition.Type) -> float:
	return _get_stat(type).value


func get_definition(type: StatDefinition.Type) -> StatDefinition:
	return _get_stat(type).definition


## Restores every stat to its initial value (start of a new day).
func reset_all() -> void:
	for type: StatDefinition.Type in _stats:
		var stat: Stat = _stats[type]
		stat.reset()
		EventBus.stat_changed.emit(type, stat.value, 0.0)


func _get_stat(type: StatDefinition.Type) -> Stat:
	assert(_stats.has(type), "Unknown stat type: %s" % type)
	return _stats[type]
