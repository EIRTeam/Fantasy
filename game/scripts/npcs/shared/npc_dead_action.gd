extends NPCActionBase

class_name NPCDeadAction

func enter() -> RexbotActionResult:
	# We are dead, so no need to process anymore
	npc.set_physics_process(false)
	return r_continue()

func tick(_time: float) -> RexbotActionResult:
	return r_continue()
