extends RefCounted

class_name RexbotAction

enum QueryResponse {
	ANSWER_UNDEFINED,
	ANSWER_YES,
	ANSWER_NO
}

var brain: RexbotBrain

func request_query(query_value: StringName) -> QueryResponse:
	return brain.query(self, query_value)

func respond_to_query(_query: StringName) -> QueryResponse:
	return QueryResponse.ANSWER_UNDEFINED

func suspend():
	pass

func unsuspend() -> RexbotActionResult:
	return r_continue()

func enter() -> RexbotActionResult:
	return r_continue()

func exit():
	pass

# Response helpers
func r_continue() -> RexbotActionResult:
	return RexbotActionResult.new(RexbotActionResult.ActionResult.CONTINUE)

func r_done() -> RexbotActionResult:
	return RexbotActionResult.new(RexbotActionResult.ActionResult.DONE)

func r_suspend_for(action: RexbotAction) -> RexbotActionResult:
	var suspend_for := RexbotActionResult.new(RexbotActionResult.ActionResult.SUSPEND_FOR)
	suspend_for.action = action
	return suspend_for
	
func r_change_to(action: RexbotAction) -> RexbotActionResult:
	var suspend_for := RexbotActionResult.new(RexbotActionResult.ActionResult.CHANGE_TO)
	suspend_for.action = action
	return suspend_for
	
func tick(_game_time: float) -> RexbotActionResult:
	return r_done()
