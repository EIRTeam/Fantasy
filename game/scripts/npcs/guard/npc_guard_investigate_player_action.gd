extends NPCActionBase

class_name NPCGuardInvestigatePlayerAction

var noise_position: Vector3

var navigating := false
var time := 0.0
var start_moving_time := 0.0

var player: HBPlayer
var tracked_player_position := Vector3.ZERO
var last_known_player_position := Vector3.ZERO

## A change in the player's last seen position bigger than this will trigger a repath
const REPATH_DISTANCE_SQUARED := 4.0 * 4.0

var wait_end_time := -1.0

## Time the NPC will spend looking around the last known player position before stopping the search
const WAIT_TIME := 4.0

func _init(_player: HBPlayer) -> void:
	player = _player
	last_known_player_position = player.player_movement.global_position
	tracked_player_position = player.player_movement.global_position
	start_moving_time = 1.0
func enter() -> RexbotActionResult:
	npc.heard_something_suspicious.emit()
	return r_continue()

func tick(delta: float) -> RexbotActionResult:
	time += delta
	
	var are_we_dead_query_result := request_query(&"are_we_dead")
	if are_we_dead_query_result == QueryResponse.ANSWER_YES:
		return r_done()
	
	if (npc as NPCGuard).player_in_sight_duration > 0.0:
		last_known_player_position = player.player_movement.global_position
	
	if start_moving_time > time:
		return r_continue()
	
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
