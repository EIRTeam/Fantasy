extends NPCActionBase

class_name NPCPatrolAction

var target_patrol_point := -1
var next_movement_time := 0.0
var time := 0.0
var waiting := false

func get_caution_fill_rate_multiplier(distance_to_player: float) -> float:
	# TODO: Implement this properly, see https://github.com/EIRTeam/Fantasy/issues/5
	if distance_to_player < NPCBase.NPCVision.npc_vision_near_range_cvar.get_float():
		return 3.0
	elif distance_to_player < NPCBase.NPCVision.npc_vision_medium_range_cvar.get_float():
		return 2.0
	elif distance_to_player < NPCBase.NPCVision.npc_vision_far_range_cvar.get_float():
		return 1.0
	return 0.0
	
func enter() -> RexbotActionResult:
	var patrol_route_positions := npc.patrol_route.path_points
	assert(patrol_route_positions.size() > 0)
	var patrol_route_distances: Array[float]
	var patrol_route_sorted_incides: Array[int]
	
	patrol_route_sorted_incides.resize(patrol_route_positions.size())
	patrol_route_distances.resize(patrol_route_positions.size())
	
	for i in range(patrol_route_positions.size()):
		patrol_route_distances[i] = patrol_route_positions[i].position.distance_to(npc.global_position)
		patrol_route_sorted_incides[i] = i
	
	patrol_route_sorted_incides.sort_custom(func(idx_a: int, idx_b: int):
		var dist_a := patrol_route_distances[idx_a]
		var dist_b := patrol_route_distances[idx_b]
		return dist_a < dist_b
	)
	
	target_patrol_point = patrol_route_sorted_incides[0]
	
	npc.navigation.begin_navigating_to(patrol_route_positions[target_patrol_point].position, npc.npc_settings.movement_speed_patrol)
	
	return r_continue()

func exit():
	npc.navigation.abort_navigation()
	
func tick(delta: float) -> RexbotActionResult:
	time += delta
	
	var are_we_dead_query_result := request_query(&"are_we_dead")
	if are_we_dead_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	var suspicious_query_result := request_query(&"did_we_hear_anything_suspicious")
	if suspicious_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	
	var player_visible_query_result := request_query(&"can_we_see_the_player")
	if player_visible_query_result == QueryResponse.ANSWER_YES:
		var dist_to_player := HBPlayer.current.global_position.distance_to(npc.global_position)
		var fill_rate := npc.vision.get_caution_fill_rate_multiplier(dist_to_player)
		if npc.vision.suspicion_meter_stage != NPCBase.NPCVision.SuspicionMeterStage.SUSPICIOUS:
			npc.vision.suspicion_meter_stage = NPCBase.NPCVision.SuspicionMeterStage.SUSPICIOUS
			npc.vision.suspicion_meter = 0.0
		npc.vision.increase_suspicion_meter(fill_rate * delta)
		if npc.vision.suspicion_meter == 1.0:
			# SAW THE PLAYER! Investigate NOW
			return r_suspend_for(NPCGuardInvestigatePlayerAction.new(HBPlayer.current))
	elif npc.vision.suspicion_meter_stage != NPCBase.NPCVision.SuspicionMeterStage.NONE:
		npc.vision.decay_suspicion_meter(delta, true)
	
	if npc.navigation.is_navigation_finished() and not waiting:
		waiting = true
		var nav_points := npc.patrol_route.path_points
		next_movement_time = time + nav_points[target_patrol_point].wait_time
		target_patrol_point = (target_patrol_point + 1) % nav_points.size()
		return r_continue()
	
	if waiting and time < next_movement_time:
		return r_continue()
	if waiting:
		waiting = false
		var nav_points := npc.patrol_route.path_points
		var settings := npc.npc_settings
		npc.navigation.begin_navigating_to(nav_points[target_patrol_point].position, npc.npc_settings.movement_speed_patrol)

	return r_continue()
