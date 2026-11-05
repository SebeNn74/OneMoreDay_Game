class_name DefeatScreen
extends EndScreen
## Defeat screen: shows why the day was lost.

@onready var _reason_label: Label = %ReasonLabel


func _ready() -> void:
	var result: DayResult = SceneManager.last_result
	var cause: StatDefinition = result.depleted_stat if result != null else null
	var has_reason: bool = cause != null and not cause.depletion_message.is_empty()

	_reason_label.visible = has_reason
	if has_reason:
		_reason_label.text = cause.depletion_message
