class_name RexbotBrain

var intentions: Array[RexbotIntention]
var actor: Node
var debug_label: Label3D

static var rexbot_debug_cvar := CVar.create(&"rexbot_debug", TYPE_BOOL, false, "Enables rexbot debugging as overlaid text")

func query(from_action: RexbotAction, p_query: StringName) -> RexbotAction.QueryResponse:
	for intention in intentions:
		var response := intention.query(p_query, from_action)
		if response != RexbotAction.QueryResponse.ANSWER_UNDEFINED:
			return response
	return RexbotAction.QueryResponse.ANSWER_UNDEFINED

func tick(delta: float):
	for intention in intentions:
		intention.tick(delta)
	if rexbot_debug_cvar.get_bool():
		if not debug_label:
			# HACK-y
			if actor is Node3D:
				debug_label = Label3D.new()
				debug_label.no_depth_test = true
				debug_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				debug_label.pixel_size = 0.001
				debug_label.fixed_size = true
				actor.add_child(debug_label)
				debug_label.position.y += 0.6
		
		if debug_label:
			var action_stack := intentions[0].action_stack
			var debug_text := ""
			for i in range(action_stack.size()-1, -1, -1):
				if not debug_text.is_empty():
					debug_text += " < "
				debug_text += action_stack[i].get_script().get_global_name()
			debug_label.text = debug_text
	elif debug_label:
		debug_label.queue_free()
		debug_label = null
