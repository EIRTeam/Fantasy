extends Node

class_name GameWorld

static var singleton: GameWorld
var state: GameState

signal alert_state_changed(new_state: GameState.AlertState)
signal alert_time_left_updated(new_time_left: float)

func _init() -> void:
	name = "GameWorld"
	Engine.get_main_loop().root.add_child.call_deferred(self)
	singleton = self
	state = GameState.new()

static func get_singleton() -> GameWorld:
	# TODO: Make this not lazily initialized
	if not singleton:
		var _s := GameWorld.new()
	return singleton

func _process(delta: float) -> void:
	state.game_time += delta
	

func notify_player_spotted(player_location: Vector3):
	state.last_known_player_position = player_location
	state.last_player_spot_time = state.game_time

func begin_alert(alert_state: GameState.AlertState):
	print("BEGIN", alert_state)
	if alert_state == state.alert_state:
		return
	
	match alert_state:
		GameState.AlertState.CLEAR:
			state.alert_state = alert_state
	state.alert_state = alert_state
	
	alert_state_changed.emit(alert_state)
