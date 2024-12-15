extends NPCActionBase

class_name NPCGuardCombatMain

const ALERT_START_GRACE_PERIOD := 2.0

var alert_raise_timer: SceneTreeTimer
var player_spotted_by_us: bool

func _init(_player_spotted_by_us := false) -> void:
	player_spotted_by_us = _player_spotted_by_us
func are_we_dead() -> bool:
	return npc.health <= 0.0

func are_we_in_alert() -> bool:
	return GameWorld.get_singleton().state.alert_state == GameWorld.get_singleton().state.AlertState.ALERT

func enter() -> RexbotActionResult:
	if player_spotted_by_us:
		npc.notify_saw_something_alarming()
		alert_raise_timer = npc.get_tree().create_timer(ALERT_START_GRACE_PERIOD)
	if are_we_in_alert():
		return r_change_to(NPCGuardCombatShootPlayer.new())
	return r_continue()
	
func tick(_time: float) -> RexbotActionResult:
	if alert_raise_timer:
		if alert_raise_timer.time_left > 0.0:
			return r_continue()
		else:
			GameWorld.get_singleton().begin_alert(GameState.AlertState.ALERT)
	if are_we_dead():
		return r_done()
	return r_done()
