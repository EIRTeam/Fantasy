extends NPCActionBase

class_name NPCInvestigateNoiseAction

var noise_position: Vector3

var time := 0.0
var start_moving_time := 0.0
var navigating := false

func _init(_noise_position: Vector3) -> void:
	noise_position = _noise_position

func enter() -> RexbotActionResult:
	npc.heard_something_suspicious.emit()
	return r_continue()

func tick(delta: float) -> RexbotActionResult:
	time += delta
	var are_we_dead_query_result := request_query(&"are_we_dead")
	if are_we_dead_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	
	if time >= 2.0:
		if not navigating:
			navigating = true
			npc.navigation.begin_navigating_to(noise_position, npc.npc_movement.MAX_MOVE_SPEED)
			return r_continue()
	else:
		return r_continue()
		
	if npc.navigation.is_navigation_finished():
		return r_change_to(NPCLookAroundAction.new())
		r_done()
	return r_continue()