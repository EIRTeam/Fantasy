extends NPCActionBase
## NPC Looks around, trying to find something of interest

class_name NPCLookAroundAction

var time := 0.0
var look_around_counter := 0
var next_look_around_time := 0.0
const LOOK_STAGE_DURATION := 3.0

func enter() -> RexbotActionResult:
	# Look back
	npc.npc_aiming.aim_at_position(npc.global_position - npc.get_forward() * 1000.0, LOOK_STAGE_DURATION)
	next_look_around_time = time + LOOK_STAGE_DURATION
	return r_continue()

func tick(delta: float) -> RexbotActionResult:
	time += delta
	if time >= next_look_around_time:
		look_around_counter += 1
		# One more round
		if look_around_counter == 1:
			npc.npc_aiming.aim_at_position(npc.global_position - npc.get_forward() * 1000.0, LOOK_STAGE_DURATION)
			next_look_around_time = time + LOOK_STAGE_DURATION
		else:
			debug_npc_talk("Must have been my imagination...")
			return r_done()
	return r_continue()
