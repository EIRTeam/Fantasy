extends NPCActionBase

class_name NPCGuardMainAction

func has_patrol_route() -> bool:
	return npc.patrol_route and not npc.patrol_route.path_points.is_empty()

func tick(delta: float) -> RexbotActionResult:
	if has_patrol_route():
		return r_suspend_for(NPCPatrolAction.new())
	return r_continue()

func can_see_player() -> bool:
	var can_see_player := false
	for entity in (npc as NPCGuard).vision.visible_entities:
		if entity is HBPlayer:
			return true
	return false

func respond_to_query(query: StringName) -> QueryResponse:
	match query:
		&"did_we_hear_anything_suspicious":
			return QueryResponse.ANSWER_YES if can_see_player() else QueryResponse.ANSWER_NO
	return QueryResponse.ANSWER_UNDEFINED
