extends NPCActionBase

class_name NPCGuardInvestigatePlayerAction

var noise_position: Vector3

var navigating := false
var time := 0.0
var start_moving_time := 0.0

var player: HBPlayer
var tracked_player_position := Vector3.ZERO

## A change in the player's last seen position bigger than this will trigger a repath
const REPATH_DISTANCE_SQUARED := 4.0 * 4.0

var wait_end_time := -1.0

## Time the NPC will spend looking around the last known player position before stopping the search
const WAIT_TIME := 4.0

## If we see the player from this distance, trigger an instant alert
const ALERT_DISTANCE_THRESHOLD := 3.0

func _init(_player: HBPlayer) -> void:
	player = _player
	GameWorld.get_singleton().notify_player_spotted(player.player_movement.global_position)
	start_moving_time = 1.0
func enter() -> RexbotActionResult:
	npc.heard_something_suspicious.emit()
	debug_npc_talk("Who's that?")
	return r_continue()

func exit():
	npc.navigation.abort_navigation()

func tick(delta: float) -> RexbotActionResult:
	time += delta
	
	var are_we_in_alert_query_result := request_query(&"are_we_in_alert")
	if are_we_in_alert_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	
	var are_we_dead_query_result := request_query(&"are_we_dead")
	if are_we_dead_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	
	if (npc as NPCGuard).player_in_sight_duration > 0.0:
		GameWorld.get_singleton().notify_player_spotted(player.player_movement.global_position)
		if can_we_see_the_player():
			var player_distance := GameWorld.get_singleton().state.last_known_player_position.distance_to(npc.npc_movement.global_position)
			if player_distance < NPCGuard.instant_alert_closeness_cvar.get_float():
				return r_done()
	
	if start_moving_time > time:
		return r_continue()
	
	var last_known_player_position = GameWorld.get_singleton().state.last_known_player_position
	if last_known_player_position.distance_squared_to(tracked_player_position) > REPATH_DISTANCE_SQUARED or not navigating:
		tracked_player_position = last_known_player_position
		npc.navigation.begin_navigating_to(tracked_player_position, npc.npc_settings.movement_speed)
		navigating = true
		return r_continue()
	
	if npc.navigation.is_navigation_finished():
		if wait_end_time == -1.0:
			wait_end_time = time + WAIT_TIME
		if wait_end_time < time:
			# Couldn't find the player, return to my old job
			print("Must have been my imagination...")
			return r_done()
	return r_continue()
