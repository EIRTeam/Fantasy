extends NPCActionBase

class_name NPCGuardChasePlayer

var current_chase_target_position := Vector3.ZERO
const REPATH_DELTA := 1.5

func enter() -> RexbotActionResult:
	current_chase_target_position = GameWorld.get_singleton().state.last_known_player_position
	npc.navigation.begin_navigating_to(current_chase_target_position, npc.npc_movement.MAX_MOVE_SPEED)
	return r_continue()

func tick(time: float) -> RexbotActionResult:
	var diff := current_chase_target_position.distance_to(GameWorld.get_singleton().state.last_known_player_position)
	if diff > REPATH_DELTA:
		current_chase_target_position = GameWorld.get_singleton().state.last_known_player_position
		npc.navigation.begin_navigating_to(current_chase_target_position, npc.npc_movement.MAX_MOVE_SPEED)
	
	if not can_we_see_the_player() and npc.navigation.is_navigation_finished():
		return r_done()
	return r_continue()
