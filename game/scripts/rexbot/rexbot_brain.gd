class_name RexbotBrain

var intentions: Array[RexbotIntention]
var actor: Node

func query(from_action: RexbotAction, p_query: StringName) -> RexbotAction.QueryResponse:
	for intention in intentions:
		var response := intention.query(p_query, from_action)
		if response != RexbotAction.QueryResponse.ANSWER_UNDEFINED:
			return response
	return RexbotAction.QueryResponse.ANSWER_UNDEFINED

func tick(delta: float):
	for intention in intentions:
		intention.tick(delta)
