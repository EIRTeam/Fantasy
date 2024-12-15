extends CanvasLayer

@onready var camo_index_label: Label = get_node("%CamoIndexLabel")
@onready var crosshair: Crosshair = get_node("%Crosshair")
@onready var alert_state_label: Label = get_node("%AlertStatusLabel")
@onready var bloody_overlay: ColorRect = get_node("%Bloody")
@onready var health_label: Label = get_node("%HealthLabel")
var bloody_overlay_tween: Tween

func update_alert_status_label(new_state: GameState.AlertState):
	alert_state_label.text = GameState.AlertState.find_key(new_state)
	var color := Color()
	match new_state:
		GameState.AlertState.ALERT:
			color = Color.RED
		GameState.AlertState.CAUTION:
			color = Color.YELLOW
		GameState.AlertState.CLEAR:
			color = Color.WHITE
	alert_state_label.add_theme_color_override(&"font_color", color)

func _ready() -> void:
	var game_world := GameWorld.get_singleton()
	game_world.alert_state_changed.connect(update_alert_status_label)
	update_alert_status_label(GameState.AlertState.CLEAR)
	_on_player_health_changed(0.0, 100.0)

func update_camo_index(new_camo_index: float):
	camo_index_label.text = "%.0f%%" % (new_camo_index*100.0)

func _on_player_weapon_equipped(weapon: WeaponInstance):
	if weapon is WeaponInstanceFirearmBase:
		crosshair.spread_angle = weapon.firearm_weapon_data.base_spread

func _on_player_weapon_unequipped(_weapon: WeaponInstance):
	crosshair.spread_angle = 0.0

func _on_player_weapon_spread_changed(new_spread: float) -> void:
	crosshair.spread_angle = new_spread


func _on_player_health_changed(prev_health: float, new_health: float) -> void:
	if prev_health > new_health:
		if bloody_overlay_tween:
			bloody_overlay_tween.kill()
		bloody_overlay_tween = create_tween()
		bloody_overlay_tween.tween_property(bloody_overlay, "self_modulate:a", 0.0, 0.5).from(0.15)
		health_label.text = "Health: %d" % new_health
