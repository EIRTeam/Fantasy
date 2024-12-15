extends WeaponData

class_name WeaponDataFirearmBase

enum FireMode {
	AUTO,
	SEMIAUTO
}

var ammo_per_clip := 30
var ammo_in_clip := 30
var ammo_total := 60
var reload_duration := 2.0
var rounds_per_minute := 700
var damage_range := 1000.0
var damage := 30.0
## Spread of the gun from the first shot, as an angle
@export_range(0.0, 90.0, 0.001, "radians_as_degrees") var base_spread := 0.0

## Spread gained for each shot
@export_range(0.0, 90.0, 0.001, "radians_as_degrees") var spread_gain_per_shot := 0.0

## Spread lost per second
@export_range(0.0, 90.0, 0.001, "radians_as_degrees") var spread_decay := 0.0

## Maximum possible spread of the gun
@export_range(0.0, 90.0, 0.001, "radians_as_degrees") var max_spread := 0.0
