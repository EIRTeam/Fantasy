extends NPCActionBase

class_name NPCGuardMainAction

const PLAYER_SUSPICION_TIME_THRESHOLD := 0.3

func has_patrol_route() -> bool:
	return npc.patrol_route and not npc.patrol_route.path_points.is_empty()

func unsuspend() -> RexbotActionResult:
	if are_we_dead():
		return r_change_to(NPCDeadAction.new())
	return r_continue()

func tick(_delta: float) -> RexbotActionResult:
	if are_we_dead():
		return r_done()
	if are_we_in_combat():
		return r_suspend_for(NPCGuardCombatMain.new())
	if npc.hearing.heard_points.size() > 0:
		return r_suspend_for(NPCInvestigateNoiseAction.new(npc.hearing.heard_points[0]))
	if has_patrol_route() and NavigationServer3D.map_get_iteration_id(npc.get_world_3d().navigation_map) != 0:
		return r_suspend_for(NPCPatrolAction.new())
	return r_continue()

func can_see_player() -> bool:
	for entity in (npc as NPCGuard).vision.visible_entities:
		if entity is HBPlayer:
			return true
	return false

func are_we_in_combat() -> bool:
	return GameWorld.get_singleton().state.alert_state == GameState.AlertState.COMBAT

func are_we_in_evasion() -> bool:
	return GameWorld.get_singleton().state.alert_state == GameState.AlertState.EVASION

func are_we_dead() -> bool:
	return npc.health <= 0.0

func respond_to_query(query: StringName) -> QueryResponse:
	match query:
		&"are_we_in_evasion":
			return QueryResponse.ANSWER_YES if are_we_in_evasion() else QueryResponse.ANSWER_NO
		&"are_we_in_combat":
			return QueryResponse.ANSWER_YES if are_we_in_combat() else QueryResponse.ANSWER_NO
		&"are_we_dead":
			return QueryResponse.ANSWER_YES if are_we_dead() else QueryResponse.ANSWER_NO
		&"did_we_hear_anything_suspicious":
			return QueryResponse.ANSWER_YES if npc.hearing.heard_points.size() > 0 else QueryResponse.ANSWER_NO
		&"can_we_see_the_player":
			return QueryResponse.ANSWER_YES if can_see_player() else QueryResponse.ANSWER_NO
	return QueryResponse.ANSWER_UNDEFINED
