extends CanvasLayer

@onready var camo_index_label: Label = get_node("%CamoIndexLabel")
@onready var crosshair: Crosshair = get_node("%Crosshair")
@onready var alert_state_label: Label = get_node("%AlertStatusLabel")
@onready var bloody_overlay: ColorRect = get_node("%Bloody")
@onready var health_label: Label = get_node("%HealthLabel")
@onready var alert_meters_container: Control = get_node("%AlertMetersContainer")
var bloody_overlay_tween: Tween

var alert_meters: Dictionary[NPCBase, HBUIAlertMeter]

func update_alert_status(new_state: GameState.AlertState):
	alert_state_label.text = GameState.AlertState.find_key(new_state) + " " + str(GameWorld.get_singleton().state.alert_time_remaining)
	var color := Color()
	match new_state:
		GameState.AlertState.EVASION:
			color = Color.BLUE
		GameState.AlertState.COMBAT:
			color = Color.RED
		GameState.AlertState.ALERT:
			color = Color.YELLOW
		GameState.AlertState.CLEAR:
			color = Color.WHITE
	alert_state_label.add_theme_color_override(&"font_color", color)
	alert_meters_container.visible = new_state != GameState.AlertState.COMBAT
	

func _ready() -> void:
	var game_world := GameWorld.get_singleton()
	game_world.alert_state_changed.connect(func(new_state: GameState.AlertState): update_alert_status(new_state))
	game_world.alert_time_left_updated.connect(func(new_state: GameState.AlertState): update_alert_status(new_state))
	update_alert_status(GameState.AlertState.CLEAR)
	_on_player_health_changed(0.0, 100.0)
	
	game_world.npc_alert_meters_updated.connect(_on_npc_alert_meters_updated)

func update_camo_index(new_camo_index: float):
	camo_index_label.text = "%.0f%%" % (new_camo_index*100.0)

func _on_player_weapon_equipped(weapon: WeaponInstance):
	if weapon is WeaponInstanceFirearmBase:
		crosshair.spread_angle = weapon.firearm_weapon_data.base_spread

func _on_player_weapon_unequipped(_weapon: WeaponInstance):
	crosshair.spread_angle = 0.0

func _on_player_weapon_spread_changed(new_spread: float) -> void:
	crosshair.spread_angle = new_spread

func _on_npc_alert_meters_updated(npc: NPCBase, meter_stage: NPCBase.NPCVision.SuspicionMeterStage, meter_value: float):
	var alert_meter_ui := alert_meters.get(npc, null) as HBUIAlertMeter
	if meter_stage != NPCBase.NPCVision.SuspicionMeterStage.NONE:
		if not alert_meter_ui:
			alert_meter_ui = preload("res://scenes/ui/alert_meter.tscn").instantiate() as HBUIAlertMeter
			alert_meters_container.add_child(alert_meter_ui)
			assert(alert_meter_ui)
			alert_meters[npc] = alert_meter_ui
		# Update alert meter stuff...
		alert_meter_ui.value = meter_value
		alert_meter_ui.type = HBUIAlertMeter.AlertMeterType.SUSPICIOUS if meter_stage == NPCBase.NPCVision.SuspicionMeterStage.SUSPICIOUS else HBUIAlertMeter.AlertMeterType.ALERT
	elif alert_meter_ui:
		alert_meters.erase(npc)
		alert_meter_ui.queue_free()

func _process(_delta: float) -> void:
	if alert_meters.size() > 0:
		var cam_forward := get_viewport().get_camera_3d().get_camera_transform().basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		var camera_pos := get_viewport().get_camera_3d().get_camera_transform().origin
		
		if not cam_forward.is_normalized():
			return
		
		for npc in alert_meters:
			alert_meters[npc]._update_placement(camera_pos, cam_forward, npc.global_position)
func _on_player_health_changed(prev_health: float, new_health: float) -> void:
	if prev_health > new_health:
		if bloody_overlay_tween:
			bloody_overlay_tween.kill()
		bloody_overlay_tween = create_tween()
		bloody_overlay_tween.tween_property(bloody_overlay, "self_modulate:a", 0.0, 0.5).from(0.15)
		health_label.text = "Health: %d" % new_health
