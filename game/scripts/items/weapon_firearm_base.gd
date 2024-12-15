extends WeaponInstance

class_name WeaponInstanceFirearmBase

var firearm_weapon_data: WeaponDataFirearmBase:
	get:
		return weapon_data as WeaponDataFirearmBase

var reload_end_time := 0.0
var next_round_time := 0.0

const TRAIL_SCENE := preload("res://scenes/vfx/firearm_trail.tscn")

signal round_fired

func _init() -> void:
	weapon_data = WeaponDataFirearmBase.new()
	weapon_data.base_spread = deg_to_rad(1.0)
	weapon_data.spread_gain_per_shot = deg_to_rad(1.0)
	weapon_data.max_spread = deg_to_rad(3.0)
	weapon_data.spread_decay = deg_to_rad(5.0)

func is_reloading(shared: WeaponShared) -> bool:
	return shared.game_time < reload_end_time

func reload(shared: WeaponShared):
	# Can we reload?
	var can_reload := firearm_weapon_data.ammo_in_clip < firearm_weapon_data.ammo_per_clip
	can_reload = can_reload and firearm_weapon_data.ammo_in_clip < firearm_weapon_data.ammo_total
	if not can_reload:
		return
	if not is_reloading(shared):
		reload_end_time = shared.game_time + firearm_weapon_data.reload_duration

func randomize_direction_with_spread(spread_angle: float, direction: Vector3) -> Vector3:
	var right_axis := direction.cross(Vector3.UP).normalized()
	# Rotate right axis randomly around direction
	right_axis = right_axis.rotated(direction, randf_range(0.0, TAU))
	# Now, rotate around the rotated right axis
	var half_spread_angle := spread_angle * 0.5
	var new_direction := direction.rotated(right_axis, randf_range(-half_spread_angle, half_spread_angle))
	return new_direction
func fire_round(shared: WeaponShared):
	var layers := HBPhysicsLayers.LAYER_WORLDSPAWN | HBPhysicsLayers.LAYER_PROPS | HBPhysicsLayers.LAYER_ENTITY_HITBOXES
	var aim_normal := randomize_direction_with_spread(shared.spread, shared.actor_aim_normal)
	var ray_params := PhysicsRayQueryParameters3D.create(shared.actor_aim_origin, shared.actor_aim_origin + aim_normal * firearm_weapon_data.damage_range, layers)
	var dss := shared.actor_movement.get_world_3d().direct_space_state
	ray_params.exclude = [shared.actor_hitbox.get_body_rid()]
	var ray_intersect_result := dss.intersect_ray(ray_params)
	if ray_intersect_result.is_empty():
		# TODO: Empty hit
		return
	var object_to_damage := ray_intersect_result.collider as Node3D
	if object_to_damage.is_in_group(&"can_receive_damage") and object_to_damage.has_method(&"_receive_damage"):
		object_to_damage._receive_damage(firearm_weapon_data.damage)
	
	var trail := TRAIL_SCENE.instantiate() as FirearmTrail
	shared.actor_movement.add_child(trail)
	var muzzle := ray_params.from
	if shared.weapon_muzzle_position:
		muzzle = shared.weapon_muzzle_position
	trail.initialize(muzzle, ray_intersect_result.position, ray_intersect_result.normal, 250.0)
	round_fired.emit()
	var fire_period := 1.0 / (firearm_weapon_data.rounds_per_minute / 60.0)
	next_round_time = shared.game_time + fire_period
	# TODO: Set this up properly
	if shared.audio_playback:
		var weapon_sounds := [
			preload("res://sounds/weapons/m4a1_unsil-1.wav"),
			preload("res://sounds/weapons/m4a1_unsil-2.wav")
		]
		shared.audio_playback.play_stream(weapon_sounds.pick_random())
	
func primary(shared: WeaponShared, press_state: WeaponPressState):
	if press_state == WeaponPressState.JUST_PRESSED or press_state == WeaponPressState.HELD:
		if next_round_time <= shared.game_time:
			fire_round(shared)
