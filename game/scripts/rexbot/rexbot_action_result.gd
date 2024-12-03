class_name RexbotActionResult

enum ActionResult {
	CONTINUE,
	DONE,
	SUSPEND_FOR,
	CHANGE_TO
}

var action_result: ActionResult
var action: RexbotAction

func _init(_action_result: ActionResult) -> void:
	action_result = _action_result
