extends Node
## Autoload. Remembers what happened during the day that the endings depend on
## It only records facts and builds a RunSummary.
## EndingResolver decides which ending applies.

## Event that counts as a theft: "En el bus alguien te hurta parte del dinero".
const THEFT_EVENT_ID: String = "EV-20"
## Options that count as helping or accepting help: decision id -> option indexes.
const HELP_CHOICES: Dictionary = {
	"NPC-03": [0],
	"NPC-06": [0, 2],
}

var _helped: bool = false
var _challenge_active: bool = false
var _challenge_success: bool = false
var _challenge_failed: bool = false
var _challenge_seconds_left: float = 0.0
var _last_money_loss_was_theft: bool = false
## Frame of the last money loss. A theft cause that arrives in the same frame claims it:
## the effect is applied just before the cause is announced.
var _money_loss_frame: int = -1


func _ready() -> void:
	EventBus.stat_changed.connect(_on_stat_changed)
	EventBus.game_event_triggered.connect(_on_game_event_triggered)
	EventBus.hostile_hit.connect(_on_hostile_hit)
	EventBus.decision_resolved.connect(_on_decision_resolved)
	EventBus.challenge_started.connect(_on_challenge_started)
	EventBus.challenge_finished.connect(_on_challenge_finished)


## Forgets everything. Called when a new day starts.
func reset() -> void:
	_helped = false
	_challenge_active = false
	_challenge_success = false
	_challenge_failed = false
	_challenge_seconds_left = 0.0
	_last_money_loss_was_theft = false
	_money_loss_frame = -1


## Snapshot of the day for EndingResolver. Call it once the day is over.
func build_summary(result: DayResult) -> RunSummary:
	var summary: RunSummary = RunSummary.new()
	summary.is_victory = result.is_victory
	summary.depleted_stat = RunSummary.NO_STAT if result.depleted_stat == null else result.depleted_stat.type
	summary.money = StatsManager.get_value(StatDefinition.Type.MONEY)
	summary.energy = StatsManager.get_value(StatDefinition.Type.ENERGY)
	summary.time = StatsManager.get_value(StatDefinition.Type.TIME)
	summary.helped = _helped
	summary.challenge_active = _challenge_active
	summary.challenge_success = _challenge_success
	summary.challenge_failed = _challenge_failed
	summary.challenge_seconds_left = _challenge_seconds_left
	summary.last_money_loss_was_theft = _last_money_loss_was_theft
	return summary


func _on_stat_changed(type: StatDefinition.Type, _new_value: float, change: float) -> void:
	if type == StatDefinition.Type.MONEY and change < 0.0:
		_money_loss_frame = Engine.get_process_frames()
		_last_money_loss_was_theft = false


func _on_game_event_triggered(event: GameEvent) -> void:
	if event.id == THEFT_EVENT_ID:
		_mark_theft()


## A hostile that takes money is a thief (H-I3, H-V3), whatever its id.
func _on_hostile_hit(definition: HostileDefinition) -> void:
	if definition.hit_money < 0.0:
		_mark_theft()


func _mark_theft() -> void:
	if _money_loss_frame == Engine.get_process_frames():
		_last_money_loss_was_theft = true


func _on_decision_resolved(decision: DecisionDefinition, chosen: DecisionOption) -> void:
	if not HELP_CHOICES.has(decision.id):
		return
	var index: int = decision.options.find(chosen)
	if index in HELP_CHOICES[decision.id]:
		_helped = true


func _on_challenge_started() -> void:
	_challenge_active = true


func _on_challenge_finished(is_success: bool, seconds_left: float) -> void:
	_challenge_active = false
	_challenge_success = is_success
	_challenge_failed = not is_success
	_challenge_seconds_left = seconds_left
