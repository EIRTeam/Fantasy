class_name RexbotIntention

var brain: RexbotBrain

var action_stack: Array[RexbotAction]

func _init(_brain: RexbotBrain, initial_action: RexbotAction):
	brain = _brain
	action_stack.push_back(initial_action)
	connect_action(initial_action)

func connect_action(action: RexbotAction):
	action.brain = brain

func query(query: StringName, requesting_action: RexbotAction) -> RexbotAction.QueryResponse:
	for i in range(action_stack.size()-1, -1, -1):
		var t_action := action_stack[i]
		if requesting_action == t_action:
			continue
		var response := action_stack[i].respond_to_query(query)
		if response != RexbotAction.QueryResponse.ANSWER_UNDEFINED:
			return response
	return RexbotAction.QueryResponse.ANSWER_UNDEFINED

func respond_to_action(action: RexbotAction, response: RexbotActionResult):
	match response.action_result:
		RexbotActionResult.ActionResult.DONE:
			action_stack.resize(action_stack.size()-1)
			if action_stack.size() > 0:
				respond_to_action(action, action_stack[-1].unsuspend())
		RexbotActionResult.ActionResult.CHANGE_TO:
			assert(response.action)
			assert(!action_stack.has(response.action))
			action_stack[-1].exit()
			action_stack.resize(action_stack.size()-1)
			connect_action(response.action)
			action_stack.push_back(response.action)
			respond_to_action(action, response.action.enter())
		RexbotActionResult.ActionResult.SUSPEND_FOR:
			assert(response.action)
			assert(!action_stack.has(response.action))
			action_stack[-1].suspend()
			connect_action(response.action)
			action_stack.push_back(response.action)
			respond_to_action(action, response.action.enter())
		RexbotActionResult.ActionResult.CONTINUE:
			pass

func tick(delta: float):
	if action_stack.size() == 0:
		return
	var action := action_stack[-1]
	var response := action.tick(delta)
	respond_to_action(action, response)
