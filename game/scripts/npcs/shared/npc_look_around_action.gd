extends NPCActionBase
## NPC Looks around, trying to find something of interest

class_name NPCLookAroundAction

var time := 0.0
var look_around_counter := 0

func enter() -> RexbotActionResult:
	# Look back
	npc.look_at_target_position(npc.npc_movement.global_position - npc.get_forward() * 1000.0)
	print("LOOKMA")
	return r_continue()

func tick(delta: float) -> RexbotActionResult:
	if not npc.is_looking_at_a_target():
		look_around_counter += 1
		# One more round
		if look_around_counter == 1:
			npc.look_at_target_position(npc.npc_movement.global_position - npc.get_forward() * 1000.0)
		else:
			return r_done()
	return r_continue()
