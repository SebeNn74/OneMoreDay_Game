class_name EndingResolver
extends RefCounted
## Picks the ending of a finished day.
## Defeats are checked in this order: D-04, D-05, D-01, D-02, D-03.
## Victories: V-03, V-04, V-05, V-01, V-02 (the first one that fits).

const DEFEAT_THEFT: String = "D-04"
const DEFEAT_CHALLENGE: String = "D-05"
const DEFEAT_MONEY: String = "D-01"
const DEFEAT_ENERGY: String = "D-02"
const DEFEAT_TIME: String = "D-03"
const VICTORY_HELP: String = "V-03"
const VICTORY_CHALLENGE: String = "V-04"
const VICTORY_RICH: String = "V-05"
const VICTORY_COMFORT: String = "V-01"
const VICTORY_PLAIN: String = "V-02"


static func resolve(summary: RunSummary, catalog: EndingCatalog) -> EndingDefinition:
	var id: String = _victory_id(summary, catalog) if summary.is_victory else _defeat_id(summary)
	return catalog.find(id)


static func _defeat_id(summary: RunSummary) -> String:
	if summary.depleted_stat == StatDefinition.Type.MONEY and summary.last_money_loss_was_theft:
		return DEFEAT_THEFT
	var energy_ran_out_in_challenge: bool = (
		summary.depleted_stat == StatDefinition.Type.ENERGY and summary.challenge_active)
	if summary.challenge_failed or energy_ran_out_in_challenge:
		return DEFEAT_CHALLENGE
	match summary.depleted_stat:
		StatDefinition.Type.MONEY:
			return DEFEAT_MONEY
		StatDefinition.Type.ENERGY:
			return DEFEAT_ENERGY
	return DEFEAT_TIME


static func _victory_id(summary: RunSummary, catalog: EndingCatalog) -> String:
	if summary.helped:
		return VICTORY_HELP
	if summary.challenge_success and summary.challenge_seconds_left >= catalog.challenge_spare_seconds:
		return VICTORY_CHALLENGE
	if summary.money >= catalog.rich_money:
		return VICTORY_RICH
	if (summary.money >= catalog.comfort_money and summary.energy >= catalog.comfort_energy
			and summary.time >= catalog.comfort_time):
		return VICTORY_COMFORT
	return VICTORY_PLAIN
