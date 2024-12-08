class_name WeaponInstance

var weapon_data: WeaponData

signal holstered

enum WeaponPressState {
	JUST_PRESSED,
	HELD,
	JUST_RELEASED
}

class WeaponShared:
	var actor_movement: Node3D
	var actor_look: Node3D
	var actor_aim_origin := Vector3()
	var actor_aim_normal := Vector3()
	var actor_ghost_body: Node3D
	var weapon_muzzle: Node3D
	var game_time := 0.0
	var spread := 0.0
	var audio_playback: AudioStreamPlaybackPolyphonic

func draw():
	pass

func holster():
	pass

func init(_shared: WeaponShared):
	pass

func primary(_shared: WeaponShared, _press_state: WeaponPressState):
	pass

func secondary(_shared: WeaponShared, _press_state: WeaponPressState):
	pass

func _physics_process(_shared: WeaponShared, _delta: float):
	pass

func notify_holster():
	holstered.emit()
	holster()
