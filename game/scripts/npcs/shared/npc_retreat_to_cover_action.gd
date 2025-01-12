extends NPCActionBase

var cover_transform := Transform3D.IDENTITY

func _init(_cover_transform: Transform3D) -> void:
	cover_transform = _cover_transform

func enter() -> RexbotActionResult:
	npc.navigation.begin_navigating_to(cover_transform.origin, npc.npc_settings.movement_speed)
	return r_continue()

func tick(_delta: float) -> RexbotActionResult:
	var are_we_dead_query_result := request_query(&"are_we_dead")
	if are_we_dead_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	if npc.navigation.is_navigation_finished():
		r_done()
	return r_continue()
