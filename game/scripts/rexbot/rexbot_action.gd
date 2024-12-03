class_name RexbotAction

enum QueryResponse {
	ANSWER_UNDEFINED,
	ANSWER_YES,
	ANSWER_NO
}

var brain: RexbotBrain

# Queries
signal query_requested(query_value: StringName)

func request_query(query_value: StringName) -> QueryResponse:
	return QueryResponse.ANSWER_UNDEFINED

func respond_to_query(query: StringName) -> QueryResponse:
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
func tick(time: float) -> RexbotActionResult:
	return r_done()
