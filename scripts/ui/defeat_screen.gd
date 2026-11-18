class_name DefeatScreen
extends EndScreen
## Defeat screen: shows why the day was lost.

@onready var _reason_label: Label = %ReasonLabel


func _ready() -> void:
	var result: DayResult = SceneManager.last_result
	var reason: String = result.reason if result != null else ""
	_reason_label.visible = not reason.is_empty()
	_reason_label.text = reason
