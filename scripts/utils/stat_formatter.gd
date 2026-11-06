class_name StatFormatter
extends RefCounted
## Turns stat values into player-visible text.

## 1 money unit = $1.000 COP.
const PESOS_PER_MONEY_UNIT: int = 1000
const THOUSANDS_SEPARATOR: String = "."
const GROUP_SIZE: int = 3


static func format_value(type: StatDefinition.Type, value: float) -> String:
	match type:
		StatDefinition.Type.MONEY:
			return _format_pesos(value)
	return str(roundi(value))


static func format_change(type: StatDefinition.Type, change: float) -> String:
	var sign_text: String = "+" if change > 0.0 else "-"
	match type:
		StatDefinition.Type.MONEY:
			return sign_text + _format_pesos(absf(change))
	return "%s%d" % [sign_text, roundi(absf(change))]


static func _format_pesos(money_units: float) -> String:
	var pesos: int = roundi(money_units * PESOS_PER_MONEY_UNIT)
	var digits: String = str(absi(pesos))
	var grouped: String = ""
	while digits.length() > GROUP_SIZE:
		grouped = THOUSANDS_SEPARATOR + digits.substr(digits.length() - GROUP_SIZE) + grouped
		digits = digits.left(digits.length() - GROUP_SIZE)
	return ("-$" if pesos < 0 else "$") + digits + grouped
