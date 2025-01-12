extends Node

class_name GameWorld

static var singleton: GameWorld
var state: GameState

signal alert_state_changed(new_state: GameState.AlertState)
signal alert_time_left_updated(new_time_left: float)
signal npc_alert_meters_updated(npc: NPCBase, suspicion_meter: NPCBase.NPCVision.SuspicionMeterStage, meter_value: float)

static var evasion_duration_cvar := CVar.create(&"world_evasion_duration", TYPE_FLOAT, 25.0, "How long should the evasion phase last for")
static var alert_duration_cvar := CVar.create(&"world_alert_duration", TYPE_FLOAT, 60.0, "How long should the alert phase last for")
static var evasion_start_time := CVar.create(&"world_evasion_start_time", TYPE_FLOAT, 3.0, "How many seconds should the player be non-visible for before evasion state begins")

func _init() -> void:
	name = "GameWorld"
	Engine.get_main_loop().root.add_child.call_deferred(self)
	singleton = self
	state = GameState.new()

func notify_alert_meters_updated(npc: NPCBase, suspicion_meter_stage: NPCBase.NPCVision.SuspicionMeterStage, meter_value: float):
	npc_alert_meters_updated.emit(npc, suspicion_meter_stage, meter_value)

static func get_singleton() -> GameWorld:
	# TODO: Make this not lazily initialized
	if not singleton:
		var _s := GameWorld.new()
	return singleton

func _physics_process(delta: float) -> void:
	if state.alert_state != GameState.AlertState.CLEAR:
		if state.game_time - state.last_player_spot_time > evasion_start_time.get_float():
			if state.alert_state == GameState.AlertState.COMBAT:
				state.alert_state = GameState.AlertState.EVASION
				state.alert_time_remaining = evasion_duration_cvar.get_float()
			elif state.alert_state == GameState.AlertState.EVASION:
				if state.alert_time_remaining == 0.0:
					state.alert_state = GameState.AlertState.ALERT
					state.alert_time_remaining = alert_duration_cvar.get_float()
			elif state.alert_state == GameState.AlertState.ALERT:
				if state.alert_time_remaining == 0.0:
					state.alert_state = GameState.AlertState.CLEAR
		state.alert_time_remaining -= delta
		state.alert_time_remaining = max(state.alert_time_remaining, 0.0)
		alert_time_left_updated.emit(state.alert_time_remaining)
	#if state.alert_state >= GameState.AlertState.CAUTION:
		#if state.last_player_spot_time >= state.game_time:
			#state.alert_time_remaining = 99.0
			#alert_time_left_updated.emit(state.alert_time_remaining)
		#else:
			#state.alert_time_remaining -= delta
			#alert_time_left_updated.emit(state.alert_time_remaining)
	state.game_time += delta

func notify_player_spotted(player_location: Vector3):
	state.last_known_player_position = player_location
	state.last_player_spot_time = state.game_time

func begin_alert(alert_state: GameState.AlertState):
	if alert_state == state.alert_state:
		return
	
	match alert_state:
		GameState.AlertState.CLEAR:
			state.alert_state = alert_state
	state.alert_state = alert_state
	
	alert_state_changed.emit(alert_state)
