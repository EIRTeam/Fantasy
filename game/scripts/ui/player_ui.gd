extends CanvasLayer

@onready var camo_index_label: Label = get_node("%CamoIndexLabel")
@onready var crosshair: Crosshair = get_node("%Crosshair")

func update_camo_index(new_camo_index: float):
	camo_index_label.text = "%.0f%%" % (new_camo_index*100.0)

func _on_player_weapon_equipped(weapon: WeaponInstance):
	if weapon is WeaponInstanceFirearmBase:
		crosshair.spread_angle = weapon.firearm_weapon_data.base_spread

func _on_player_weapon_unequipped(weapon: WeaponInstance):
	crosshair.spread_angle = 0.0


func _on_player_weapon_spread_changed(new_spread: float) -> void:
	crosshair.spread_angle = new_spread
