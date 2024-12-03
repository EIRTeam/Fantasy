extends NPCActionBase

var cover_transform := Transform3D.IDENTITY

func _init(_cover_transform: Transform3D) -> void:
	cover_transform = _cover_transform

func enter() -> RexbotActionResult:
	npc.navigation.begin_navigating_to(cover_transform.origin, npc.npc_movement.MAX_MOVE_SPEED)
	return r_continue()

func tick(_delta: float) -> RexbotActionResult:
	if npc.navigation.is_navigation_finished():
		r_done()
	return r_continue()
