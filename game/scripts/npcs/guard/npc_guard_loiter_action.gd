## Loiters (wanders) around the place, trying to find a threat
extends NPCActionBase

class_name NPCGuardLoiterAction

func exit():
	npc.navigation.abort_navigation()

func tick(_delta: float) -> RexbotActionResult:
	if npc.navigation.is_navigation_finished():
		npc.navigation.navigate_to_random_point(npc.npc_settings.movement_speed)
	
	if are_we_dead():
		return r_done()
	
	if not are_we_in_evasion() and not are_we_in_combat():
		return r_done()
	
	if can_we_see_the_player():
		GameWorld.get_singleton().notify_player_spotted(HBPlayer.current.global_position)
		if are_we_in_evasion():
			GameWorld.get_singleton().begin_alert(GameState.AlertState.COMBAT)
		return r_done()
		
	return r_continue()
