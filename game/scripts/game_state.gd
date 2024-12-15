extends Resource
class_name GameState

@export var last_known_player_position: Vector3
@export var last_player_spot_time := 0.0

enum AlertState {
	CLEAR,
	CAUTION,
	ALERT
}

@export var alert_state := AlertState.CLEAR
@export var game_time := 0.0
