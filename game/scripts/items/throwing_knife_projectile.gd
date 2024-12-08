extends RigidBody3D

class_name ThrowingKnifeProjectile

const VELOCITY := 20.0 * 2.0

var from: Vector3
var progress := 0.0
var straight_flying_distance := 0.0
var direction := Vector3.FORWARD
var damage := 0.0
var dealt_damage := false

var previous_global_position := Vector3()

@onready var knife_model: Node3D = get_node("%ThrowingKnifeModel")

## Initializes the projectile
## Projectile will fly from the position given by [param p_from] towards [param p_direction]
## Initially it will follow a straight path, once [param p_straight_flying_distance] is reached it will switch
## to falling using ordinary physics
func initialize(p_from: Vector3, p_direction: Vector3, p_straight_flying_distance: float, p_damage: float):
	from = p_from
	direction = p_direction
	global_basis = Quaternion(Vector3.FORWARD, p_direction)
	global_position = p_from
	straight_flying_distance = p_straight_flying_distance
	damage = p_damage
	linear_velocity = direction * VELOCITY
	custom_integrator = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for i in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(i) as Node
		if not collider:
			continue
		if not dealt_damage:
			var object_to_damage := collider
			## HACK-y... but let's damage the NPC
			if collider.get_parent() is NPCBase:
				object_to_damage = collider.get_parent()
			if object_to_damage.is_in_group(&"can_receive_damage") and object_to_damage.has_method(&"_receive_damage"):
				object_to_damage._receive_damage(damage)
				dealt_damage = true
		
		# Don't attach to destroyables
		var can_attach_to_object := not collider is DestroyableRigidBody
		if can_attach_to_object:
			set_physics_process(false)
			_attach_to_object.call_deferred(collider)
			return
func _attach_to_object(collider: Node3D):
	process_mode = Node.PROCESS_MODE_DISABLED
	get_parent().remove_child(self)
	collider.add_child(self)
	top_level = false

func _physics_process(delta: float) -> void:
	linear_velocity = direction * VELOCITY
	if global_position.distance_to(from) >= straight_flying_distance:
		custom_integrator = false
		set_physics_process(false)
