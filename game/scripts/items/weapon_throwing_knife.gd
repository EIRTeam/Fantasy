extends WeaponInstance

class_name WeaponInstanceThrowingKnife

signal charge_started
signal charge_progressed(progress: float)
signal charge_canceled
signal knife_thrown

var charge_start_time := -1.0

const CHARGE_DURATION := 1.5

const KNIFE_PROJECTILE_SCENE := preload("res://scenes/items/throwing_knife_projectile.tscn")

const EFFECTIVE_RANGE := 20.0
const DAMAGE_LOW := 25.0
const DAMAGE_HIGH := 50.0

func calculate_damage(charge_amount: float) -> float:
	if charge_amount == 1.0:
		return DAMAGE_HIGH
	return DAMAGE_LOW

func throw_knife(shared: WeaponShared, charge_amount: float):
	var ray_origin := shared.actor_aim_origin
	var ray_normal := shared.actor_aim_normal
	
	var character_plane := Plane(ray_normal, shared.actor_look.global_position)
	var knife_origin := character_plane.project(ray_origin)
	
	var projectile: ThrowingKnifeProjectile = KNIFE_PROJECTILE_SCENE.instantiate()
	projectile.add_collision_exception_with(shared.actor_movement)
	projectile.add_collision_exception_with(shared.actor_ghost_body)
	projectile.top_level = true
	shared.actor_movement.add_child(projectile)
	projectile.initialize(knife_origin, ray_normal, EFFECTIVE_RANGE, calculate_damage(charge_amount))
	#if collider:
		#if collider.is_in_group(&"can_receive_damage") and collider.has_method(&"_receive_damage"):
			#collider._receive_damage(calculate_damage(charge_amount))
	#intersect_result.collider

func primary(shared: WeaponShared, press_state: WeaponPressState):
	if press_state == WeaponPressState.JUST_PRESSED:
		charge_started.emit()
		charge_start_time = shared.game_time
	
	if charge_start_time == -1.0:
		return
	var charge_amount := (shared.game_time - charge_start_time) / CHARGE_DURATION
	charge_amount = min(1.0, charge_amount)
	charge_progressed.emit(charge_amount)
	if press_state == WeaponPressState.JUST_RELEASED:
		throw_knife(shared, charge_amount)
		knife_thrown.emit()
		charge_start_time = -1.0

func secondary(_shared: WeaponShared, press_state: WeaponPressState):
	if press_state != WeaponPressState.JUST_PRESSED:
		return
	if charge_start_time != -1.0:
		charge_start_time = -1.0
		charge_canceled.emit()
