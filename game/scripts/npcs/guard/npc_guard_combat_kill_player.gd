extends NPCActionBase

class_name NPCGuardCombatShootPlayer

var is_firing_burst := false
var next_burst_time := 0.0
## Time to wait between bursts of fire
const INTER_BURST_WAIT_TIME := 3.0
const ATTACK_DISTANCE := 6.0

var current_chase_target_position := Vector3.ZERO
const REPATH_DELTA := 1.5

func enter() -> RexbotActionResult:
	current_chase_target_position = GameWorld.get_singleton().state.last_known_player_position
	npc.chasing.begin_chasing_entity(HBPlayer.current, npc.npc_settings.movement_speed)
	return r_continue()

func exit():
	# Ensure we are no longer chasing anything
	npc.chasing.abort_chase()

func tick(_delta: float) -> RexbotActionResult:
	if are_we_dead():
		return r_done()
	
	var player_on_sight := can_we_see_the_player()
	if not player_on_sight and npc.chasing.chasing_state == NPCBase.NPCChasing.ChasingState.TARGET_LOST:
		debug_npc_talk("Fuck, we lost him")
		return r_done()

	var game_time := GameWorld.get_singleton().state.game_time
	if player_on_sight:
		GameWorld.get_singleton().notify_player_spotted(HBPlayer.current.global_position)
		npc.npc_aiming.aim_at_position(HBPlayer.current.global_position, 3.0)
		
		if not is_firing_burst and game_time >= next_burst_time:
			const AIM_THRESHOLD := 0.85
			var aim_dot := npc.npc_aiming.get_aiming_direction().dot(npc.npc_aiming.get_target_aim_direction())
			# TODO: Additional checks here
			if aim_dot > AIM_THRESHOLD:
				is_firing_burst = true
				npc.weaponry.fire_burst()
	if is_firing_burst and not npc.weaponry.is_firing():
		next_burst_time = game_time + INTER_BURST_WAIT_TIME
		is_firing_burst = false
		
	if request_query(&"is_player_dead") == QueryResponse.ANSWER_YES:
		return r_done()
		
	if not are_we_in_combat() and not are_we_in_evasion():
		return r_done()
		
	return r_continue()
