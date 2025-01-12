extends Resource
class_name GameState

@export var last_known_player_position: Vector3
@export var last_player_spot_time := 0.0

enum AlertState {
	CLEAR,
	ALERT,
	COMBAT,
	EVASION
}

@export var alert_state := AlertState.CLEAR
@export var alert_time_remaining := 0.0
@export var game_time := 0.0
