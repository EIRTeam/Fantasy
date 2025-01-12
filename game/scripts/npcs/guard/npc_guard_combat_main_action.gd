extends NPCActionBase

class_name NPCGuardCombatMain

const ALERT_START_GRACE_PERIOD := 2.0

var alert_raise_timer: SceneTreeTimer
var player_spotted_by_us: bool

func _init(_player_spotted_by_us := false) -> void:
	player_spotted_by_us = _player_spotted_by_us
func are_we_dead() -> bool:
	return npc.health <= 0.0

func are_we_in_combat() -> bool:
	return GameWorld.get_singleton().state.alert_state == GameWorld.get_singleton().state.AlertState.COMBAT

func enter() -> RexbotActionResult:
	if player_spotted_by_us:
		npc.notify_saw_something_alarming()
		alert_raise_timer = npc.get_tree().create_timer(ALERT_START_GRACE_PERIOD)
	if are_we_in_combat():
		return r_change_to(NPCGuardCombatShootPlayer.new())
	return r_continue()
	
func unsuspend() -> RexbotActionResult:
	if can_we_see_the_player():
		return r_suspend_for(NPCGuardCombatShootPlayer.new())
	return r_continue()
	
func tick(_time: float) -> RexbotActionResult:
	if are_we_dead():
		return r_done()
	if can_we_see_the_player():
		npc.npc_aiming.aim_at_position(HBPlayer.current.global_position)
	if alert_raise_timer:
		if alert_raise_timer.time_left > 0.0:
			return r_continue()
		else:
			GameWorld.get_singleton().begin_alert(GameState.AlertState.COMBAT)
			GameWorld.get_singleton().notify_player_spotted(HBPlayer.current.global_position)
			alert_raise_timer = null
			return r_suspend_for(NPCGuardCombatShootPlayer.new())
			
	if not are_we_in_combat() and not are_we_in_evasion():
		return r_done()
	if not can_we_see_the_player():
		return r_suspend_for(NPCGuardLoiterAction.new())
	return r_done()
