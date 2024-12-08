extends NPCActionBase

class_name NPCPatrolAction

var target_patrol_point := -1
var next_movement_time := 0
var time := 0.0
var waiting := false

func enter() -> RexbotActionResult:
	var guard := npc as NPCGuard
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
	
	var player_visible_query_result := request_query(&"did_we_see_the_player")
	if player_visible_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	
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
		npc.navigation.begin_navigating_to(nav_points[target_patrol_point].position, npc.npc_settings.movement_speed_patrol)

	return r_continue()
