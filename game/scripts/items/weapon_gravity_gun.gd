extends WeaponInstance

class_name WeaponInstanceGravityGun

const GRAVITY_GUN_MAX_GRAPPLE_DISTANCE := 6.5
const GRAVITY_GUN_MAX_PULL_DISTANCE := 15.0
## Distance from the player at which to hold the grappled object
const GRAVITY_GUN_GRAPPLE_TARGET_DISTANCE := 1.5
const OBJECT_YEET_VELOCITY := 45.0
const OBJECT_YEET_ANGULAR_VELOCITY_MAX_MIN := PI*4

## Time when we are allowed to try to grab things next
var next_grab_time := 0.0
## Time when we are allowed to try to yeet things next
var next_yeet_time := 0.0

signal grappled_object
signal released_object

class GrappleInfo:
	var attachment_static_body := StaticBody3D.new()
	var attachment_joint := Generic6DOFJoint3D.new()
	var collider: RigidBody3D
	var original_mass := 0.0
	var could_sleep := false

var current_grapple: GrappleInfo

const GRAB_PARTICLES := preload("res://scenes/vfx/gravity_gun_particles.tscn")

var grab_particles: GPUParticles3D

func init(shared: WeaponShared):
	grab_particles = GRAB_PARTICLES.instantiate()
	grab_particles.emitting = false
	grab_particles.top_level = true
	shared.actor_movement.add_child(grab_particles)

func holster():
	super.holster()
	if current_grapple:
		_ungrapple()

func _grapple_object(collider: RigidBody3D, shared: WeaponShared):
	var info := GrappleInfo.new()
	info.attachment_joint.top_level = true
	info.attachment_static_body.top_level = true
	
	info.collider = collider

	info.attachment_static_body.position = collider.global_position
	info.attachment_static_body.basis = shared.actor_look.global_basis
	info.attachment_joint.position = collider.global_position
	shared.actor_movement.add_child(info.attachment_static_body)
	info.attachment_joint.node_b = info.attachment_static_body.get_path()
	info.attachment_joint.node_a = collider.get_path()
	shared.actor_movement.add_child(info.attachment_joint)
	info.original_mass = info.collider.mass
	info.collider.mass = 1.0
	info.could_sleep = info.collider.can_sleep
	info.collider.can_sleep = false
	info.collider.continuous_cd = true
	for r in [info.attachment_joint.set_param_x, info.attachment_joint.set_param_y, info.attachment_joint.set_param_z]:
		r.call(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_STIFFNESS, 5000.0)
		r.call(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_DAMPING, 15.0)
	for r in [info.attachment_joint.set_flag_x, info.attachment_joint.set_flag_y, info.attachment_joint.set_flag_z]:
		r.call(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_SPRING, true)
		r.call(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, false)
	current_grapple = info
	grappled_object.emit()

func random_angular_velocity(min_rads: float, max_rads: float):
	return Vector3(randf_range(min_rads, max_rads), randf_range(min_rads, max_rads), randf_range(min_rads, max_rads))

func _yeet_object(object: RigidBody3D, direction: Vector3):
	object.linear_velocity += direction * OBJECT_YEET_VELOCITY
	object.angular_velocity += random_angular_velocity(-OBJECT_YEET_ANGULAR_VELOCITY_MAX_MIN, OBJECT_YEET_ANGULAR_VELOCITY_MAX_MIN)

func _ungrapple():
	current_grapple.attachment_joint.queue_free()
	current_grapple.attachment_static_body.queue_free()
	current_grapple.collider.mass = current_grapple.original_mass
	current_grapple.collider.can_sleep = current_grapple.could_sleep
	current_grapple = null
	grab_particles.emitting = false
	released_object.emit()
func _physics_process(shared: WeaponShared, delta: float):
	if current_grapple:
		var direction := shared.actor_look.global_basis * Vector3.FORWARD
		var view_right := shared.actor_look.global_basis * Vector3.RIGHT
		current_grapple.attachment_static_body.global_position = current_grapple.attachment_static_body.global_position.move_toward(view_right * 0.5 + shared.actor_look.global_position + direction * GRAVITY_GUN_GRAPPLE_TARGET_DISTANCE, 20.0 * delta)
		current_grapple.attachment_static_body.global_basis = shared.actor_look.global_basis
		grab_particles.emitting = true
		grab_particles.global_position = current_grapple.collider.global_position
func primary(shared: WeaponShared, press_state: WeaponPressState):
	if press_state != WeaponPressState.JUST_PRESSED:
		return
	
	if shared.game_time < next_yeet_time:
		return
	if current_grapple:
		var collider := current_grapple.collider
		_ungrapple()
		var vp := shared.actor_look.get_window()
		var look_normal := vp.get_camera_3d().project_ray_normal(vp.size * 0.5)
		_yeet_object(collider, look_normal)
		next_yeet_time = shared.game_time + 0.5
		next_grab_time = shared.game_time + 0.5
	else:
		var vp := shared.actor_look.get_window()
		var look_origin := vp.get_camera_3d().project_ray_origin(vp.size * 0.5)
		var look_normal := vp.get_camera_3d().project_ray_normal(vp.size * 0.5)
		var ray_params := PhysicsRayQueryParameters3D.create(look_origin, look_origin + look_normal * GRAVITY_GUN_MAX_GRAPPLE_DISTANCE, HBPhysicsLayers.LAYER_PROPS)
		var dss := shared.actor_look.get_world_3d().direct_space_state
		var raycast_out := dss.intersect_ray(ray_params)
		if raycast_out.is_empty():
			return
		if raycast_out.collider is RigidBody3D and raycast_out.collider.is_in_group(&"pickupable"):
			next_yeet_time = shared.game_time + 0.5
			next_grab_time = shared.game_time + 0.5
			_yeet_object(raycast_out.collider, look_normal)
func secondary(shared: WeaponShared, press_state: WeaponPressState):
	if shared.game_time < next_grab_time:
		return
	if press_state == WeaponPressState.JUST_RELEASED:
		return
	if current_grapple:
		if press_state == WeaponPressState.JUST_PRESSED:
			_ungrapple()
			next_grab_time = shared.game_time + 0.5
		return
	var cam := shared.actor_movement.get_viewport().get_camera_3d()
	var viewport_size := shared.actor_movement.get_window().size
	var ray_origin := cam.project_ray_origin(viewport_size * 0.5)
	var ray_normal := cam.project_ray_normal(viewport_size * 0.5)
	
	var params := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_normal * GRAVITY_GUN_MAX_PULL_DISTANCE, HBPhysicsLayers.LAYER_PROPS | HBPhysicsLayers.LAYER_WORLDSPAWN)
	var ray_result := shared.actor_movement.get_world_3d().direct_space_state.intersect_ray(params)
	if not ray_result.is_empty():
		var collider := ray_result.collider as RigidBody3D
		if not collider:
			return
		var actor_position := shared.actor_movement.global_position as Vector3
		if collider.is_in_group(&"pickupable"):
			var distance := actor_position.distance_to(collider.global_position)
			if distance < GRAVITY_GUN_MAX_GRAPPLE_DISTANCE:
				_grapple_object(collider, shared)
			else:
				collider.apply_central_force(collider.global_position.direction_to(actor_position) * 550.0)
