extends RigidBody3D

class_name DamageableRigidBody

var prev_vel := Vector3()

signal damage_received(damage: float)

func _ready() -> void:
	sleeping_state_changed.connect(_on_sleeping_state_changed)
	contact_monitor = true
	max_contacts_reported = 4
	add_to_group(&"can_receive_damage")

func _receive_damage(damage: float):
	damage_received.emit(damage)

func _on_sleeping_state_changed():
	# No need to try to continue to store the previous velocity if we are sleeping...
	set_physics_process(!PhysicsServer3D.body_get_state(get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING))

func _notify_hit_by_body(other: DamageableRigidBody, other_prev_vel: Vector3, other_current_vel: Vector3):
	pass

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for i in range(state.get_contact_count()):
		var our_delta_velocity := prev_vel.length() - linear_velocity.length()
		
		var total_wiped_energy := our_delta_velocity * our_delta_velocity * mass
		var other_delta_velocity := 0.0
		var other_mass := 0.0
		var other_body := state.get_contact_collider_object(i) as DamageableRigidBody
		if other_body:
			other_delta_velocity = other_body.prev_vel.length() - other_body.linear_velocity.length()
			other_mass = other_body.mass
		
		var other_wiped_energy := other_delta_velocity * other_delta_velocity * other_mass
		total_wiped_energy += other_wiped_energy
		total_wiped_energy *= (1.0 / mass) * 2.0
		var dmg := PhysicsImpactDamage.calculate_damage(total_wiped_energy)
		if dmg > 0.0:
			damage_received.emit(dmg)

func _physics_process(delta: float) -> void:
	# big hack frfr
	prev_vel = linear_velocity
