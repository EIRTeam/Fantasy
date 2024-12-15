extends NPCActionBase

class_name NPCGuardCombatShootPlayer

var is_firing_burst := false
var next_burst_time := 0.0
var game_time := 0.0
## Time to wait between bursts of fire
const INTER_BURST_WAIT_TIME := 3.0
const ATTACK_DISTANCE := 3.0

var current_chase_target_position := Vector3.ZERO
const REPATH_DELTA := 1.5

func enter() -> RexbotActionResult:
	current_chase_target_position = GameWorld.get_singleton().state.last_known_player_position
	npc.navigation.begin_navigating_to(current_chase_target_position, npc.npc_movement.MAX_MOVE_SPEED)
	return r_continue()

func tick(delta: float) -> RexbotActionResult:
	game_time += delta
	
	if are_we_dead():
		return r_done()
	
	var player_on_sight := can_we_see_the_player()
	
	if player_on_sight and HBPlayer.current.player_movement.global_position.distance_to(npc.npc_movement.global_position) < ATTACK_DISTANCE:
		npc.navigation.abort_navigation()
	
	if not player_on_sight and npc.navigation.is_navigation_finished():
		return r_done()

	if can_we_see_the_player():
		GameWorld.get_singleton().notify_player_spotted(HBPlayer.current.global_position)
		npc.aiming.aim_at_position(HBPlayer.current.player_movement.global_position, 3.0)
		
		if not is_firing_burst and game_time >= next_burst_time:
			const AIM_THRESHOLD := 0.85
			var aim_dot := npc.aiming.get_aiming_direction().dot(npc.aiming.get_target_aim_direction())
			# TODO: Additional checks here
			if aim_dot > AIM_THRESHOLD:
				is_firing_burst = true
				npc.weaponry.fire_burst()
	if is_firing_burst and not npc.weaponry.is_firing():
		next_burst_time = game_time + INTER_BURST_WAIT_TIME
		is_firing_burst = false
		
	# Ensure we continue chasing the player
	var last_known_player_position := GameWorld.get_singleton().state.last_known_player_position
	var diff := current_chase_target_position.distance_to(last_known_player_position)
	if diff > REPATH_DELTA or (not npc.navigation.active and not player_on_sight and npc.npc_movement.global_position.distance_to(current_chase_target_position) > npc.navigation.CLOSENESS_THRESHOLD):
		current_chase_target_position = GameWorld.get_singleton().state.last_known_player_position
		npc.navigation.begin_navigating_to(current_chase_target_position, npc.npc_movement.MAX_MOVE_SPEED)
		
	if request_query(&"is_player_dead") == QueryResponse.ANSWER_YES:
		return r_done()
		
	if request_query(&"are_we_in_alert") != QueryResponse.ANSWER_YES:
		return r_done()
		
	return r_continue()
