class_name HBBaseMovement

## Emitted when snapped, either when going up slopes/stairs or going down slopes
signal movement_snapped

var desired_velocity := Vector3()

const GRAVITY_ACCEL := 1.0
const MAX_VERTICAL_SPEED := 10.0
const ACCELERATION := 100.0
var max_movement_speed := 5.0
const MAX_CROUCHING_MOVE_SPEED := 2.0
const MAX_SLOPE_ANGLE := 60.0
const MAX_STEP_HEIGHT := 0.3
const MIN_STEP_DEPTH := 0.1
const SNAP_TO_GROUND_HEIGHT := 0.6

var vertical_velocity := 0.0
var effective_velocity := Vector3.ZERO

enum MovementPass {
	LATERAL,
	GRAVITY,
	SNAP
}

var grounded := false

class MovementIterationResult:
	var done := false
	var hit := false
	var movement_snapped := false
	var remaining_velocity := Vector3()
	var new_transform := Transform3D()
	var kinematic_collision_result: PhysicsTestMotionResult3D

class MovementPassResult:
	var hit := false
	var movement_snapped := false

enum Stance {
	STANDING,
	CROUCHING
}

var stance_shapes: Array[Shape3D]

var owner_node: Node3D
var radius: float
var body: RID

var current_stance_idx := 0

func get_desired_velocity() -> Vector3:
	return Vector3()

func initialize(_radius: float, _stance_heights: Array[float], _owner_node: Node3D):
	assert(!_stance_heights.is_empty())
	body = PhysicsServer3D.body_create()
	owner_node = _owner_node
	radius = _radius
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_attach_object_instance_id(body, _owner_node.get_instance_id())
	PhysicsServer3D.body_set_space(body, _owner_node.get_world_3d().space)
	for i in range(_stance_heights.size()):
		var stance_height := _stance_heights[i]
		var cylinder := CylinderShape3D.new()
		cylinder.radius = _radius
		cylinder.height = stance_height
		stance_shapes.push_back(cylinder)
		PhysicsServer3D.body_add_shape(body, cylinder.get_rid())
		PhysicsServer3D.body_set_shape_disabled(body, i, i != 0)
	PhysicsServer3D.body_set_collision_layer(body, HBPhysicsLayers.LAYER_ENTITY_MOVEMENT_BOXES)
	PhysicsServer3D.body_set_collision_mask(body, HBPhysicsLayers.LAYER_WORLDSPAWN | HBPhysicsLayers.LAYER_PROPS)

func _plane_project(normal: Vector3, velocity: Vector3):
	var out := Plane(normal).project(velocity).normalized()
	out *= velocity.length()
	return out

class StairSnapResult:
	var success := false
	var resulting_position := Vector3()

func _test_move(trf: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D, margin := 0.001) -> bool:
	var test_motion_params := PhysicsTestMotionParameters3D.new()
	test_motion_params.from = trf
	test_motion_params.motion = motion
	return PhysicsServer3D.body_test_motion(body, test_motion_params, result)

func _try_snap_up_stair(movement_direction: Vector3, starting_trf: Transform3D) -> StairSnapResult:
	var out := StairSnapResult.new()
	# Try casting up
	var stair_up_collision := PhysicsTestMotionResult3D.new()
	if _test_move(starting_trf, Vector3(0.0, MAX_STEP_HEIGHT, 0.0), stair_up_collision):
		return out
	# Now let's try casting to our new stair location
	var stair_down_collision := PhysicsTestMotionResult3D.new()
	starting_trf.origin += Vector3(0.0, MAX_STEP_HEIGHT, 0.0)
	if not _test_move(starting_trf, Vector3(0.0, -MAX_STEP_HEIGHT, 0.0) + movement_direction * MIN_STEP_DEPTH, stair_down_collision):
		return out
	
	# Finally, check if the surface we hit on the way down is walkable
	var motion_angle := acos(stair_down_collision.get_collision_normal().dot(Vector3.UP))
	if motion_angle > deg_to_rad(MAX_SLOPE_ANGLE):
		return out
	out.resulting_position = starting_trf.origin + stair_down_collision.get_travel()
	out.success = true
	return out
	
## Movement iteration, returns true if we are done
func _move_iter(starting_trf: Transform3D, motion: Vector3, desired_movement_direction: Vector3, movement_pass: MovementPass) -> MovementIterationResult:
	const MOTION_MARGIN := 0.001
	var out_result := MovementIterationResult.new()
	var shape_cast_result := PhysicsTestMotionResult3D.new()
	out_result.new_transform = starting_trf
	if not _test_move(starting_trf, motion, shape_cast_result, MOTION_MARGIN):
		out_result.done = true
		out_result.new_transform.origin += motion
		return out_result
	out_result.kinematic_collision_result = shape_cast_result
	out_result.hit = true
	
	var snapped_to_surface := shape_cast_result.get_travel()
	var remainder := shape_cast_result.get_remainder()
	
	# We travelled a bit too little, so let's pretend we didn't travel at all
	if snapped_to_surface.length() < MOTION_MARGIN:
		snapped_to_surface = Vector3.ZERO
	
	out_result.new_transform.origin = starting_trf.origin + snapped_to_surface
	
	var cast_normal := shape_cast_result.get_collision_normal()
	var angle := cast_normal.angle_to(Vector3.UP)
	if angle <= deg_to_rad(MAX_SLOPE_ANGLE):
		remainder = _plane_project(cast_normal, remainder)
		# Prevent sliding down slopes by doing nothing
		if movement_pass == MovementPass.GRAVITY or movement_pass == MovementPass.SNAP:
			out_result.done = true
			return out_result
	else:
		if movement_pass == MovementPass.LATERAL:
			# Attempt stair step
			var snap_result := _try_snap_up_stair(desired_movement_direction, out_result.new_transform)
			if snap_result.success:
				var actual_travel := (snap_result.resulting_position - starting_trf.origin)
				var actual_travel_length := actual_travel.length()-MOTION_MARGIN
				# This may sometimes be negative, this is intentional (for conservation of energy)
				# otherwise it looks like we are going up the stairs faster than should be possible
				var actual_remainder := motion.length() - actual_travel_length
				out_result.new_transform.origin = snap_result.resulting_position
				remainder = motion * actual_remainder
				out_result.done = true
				out_result.movement_snapped = true
			else:
				# Handle sliding along walls
				var lateral_normal := shape_cast_result.get_collision_normal()
				lateral_normal.y = 0.0
				lateral_normal = lateral_normal.normalized()
				var lateral_desired_movement := desired_movement_direction
				lateral_desired_movement.y = 0.0
				lateral_desired_movement = lateral_desired_movement.normalized()
				var wall_move_scale := 1.0 - lateral_normal.dot(-lateral_desired_movement)
				remainder = _plane_project(lateral_normal, remainder) * wall_move_scale
		
	out_result.remaining_velocity = remainder
	
	return out_result

func _lateral_pass():
	pass
	
func get_max_move_speed() -> float:
	# TODO: Readd this
	#match stance:
		#Stance.CROUCHING:
			#return MAX_CROUCHING_MOVE_SPEED
	return max_movement_speed
	
func _handle_collision(velocity: Vector3, collision_result: PhysicsTestMotionResult3D):
	for i in range(collision_result.get_collision_count()):
		var body_rid := collision_result.get_collider_rid(i)
		if PhysicsServer3D.body_get_mode(body_rid) != PhysicsServer3D.BODY_MODE_RIGID and PhysicsServer3D.body_get_mode(body_rid) != PhysicsServer3D.BODY_MODE_RIGID_LINEAR:
			continue
		var v1 := velocity
		const PMASS := 15.0
		
		var body_pos := (PhysicsServer3D.body_get_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin
		var coll_normal := collision_result.get_collision_normal(i)
		var vel_along_normal := v1.dot(-coll_normal)
		var collision_point_relative := collision_result.get_collision_point(i) - body_pos
		var force := (vel_along_normal * (-coll_normal)) * PMASS
		DebugOverlay.horz_arrow(collision_result.get_collision_point(i), collision_result.get_collision_point(i) + force.normalized(), 0.25, Color.GREEN, false, 0.25)
		PhysicsServer3D.body_apply_force(body_rid, force * PMASS, collision_point_relative)
func _do_movement_pass(movement_pass: MovementPass, delta: float) -> MovementPassResult:
	var current_transform := owner_node.global_transform
	var remaining_velocity := Vector3.ZERO
	var desired_input := Vector3.ZERO
	
	match movement_pass:
		MovementPass.SNAP:
			remaining_velocity = Vector3(0, -SNAP_TO_GROUND_HEIGHT, 0.0)
		MovementPass.LATERAL:
			desired_input = get_desired_velocity().normalized()
			desired_velocity = get_desired_velocity()
			remaining_velocity = desired_velocity * delta
		MovementPass.GRAVITY:
			vertical_velocity = move_toward(vertical_velocity, -MAX_VERTICAL_SPEED, GRAVITY_ACCEL * delta)
			# Since we use this for grounded detection, it should at the very least be negative motion margin
			const MOTION_MARGIN := 0.001
			remaining_velocity.y = min(-MOTION_MARGIN, vertical_velocity * delta)
	var result := MovementPassResult.new()
	
	for i in range(3):
		var iter_result := _move_iter(current_transform, remaining_velocity, desired_input, movement_pass)
		if iter_result.hit:
			if movement_pass == MovementPass.LATERAL:
				_handle_collision(desired_velocity, iter_result.kinematic_collision_result)
		current_transform = iter_result.new_transform
		remaining_velocity = iter_result.remaining_velocity
		result.movement_snapped = iter_result.movement_snapped if iter_result.movement_snapped else result.movement_snapped
		result.hit = iter_result.hit if iter_result.hit else result.hit
		if iter_result.done:
			break
	if movement_pass != MovementPass.SNAP or result.hit:
		# SNAP pass doesn't apply the new transform unless we actually snapped
		owner_node.global_transform = current_transform
	return result

func try_change_stance(p_new_stance: int) -> bool:
	var shape := stance_shapes[p_new_stance]
	var inters := PhysicsShapeQueryParameters3D.new()
	inters.transform = owner_node.global_transform
	# We need this, otherwise stance change is sometimes rejected for some reason...
	inters.transform.origin += Vector3(0.0, 0.01, 0.0)
	inters.collision_mask = HBPhysicsLayers.LAYER_WORLDSPAWN
	inters.shape_rid = shape.get_rid()
	
	var intersections := owner_node.get_world_3d().direct_space_state.intersect_shape(inters, 1)
	var can_change_stance := intersections.size() == 0
	if can_change_stance:
		current_stance_idx = p_new_stance
	else:
		print("REJECT STANCE CHANGE!", intersections)
	return can_change_stance
func advance(delta: float) -> void:
	var prev_position := owner_node.global_position
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, owner_node.global_transform)
	
	var lateral_pass := _do_movement_pass(MovementPass.LATERAL, delta)
	var gravity_pass := _do_movement_pass(MovementPass.GRAVITY, delta)
	var pre_snap_position := owner_node.global_position
	var did_movement_snap := lateral_pass.movement_snapped
	if gravity_pass.hit:
		grounded = true
	elif not get_desired_velocity().is_zero_approx():
		if grounded:
			grounded = false
			var snap_pass := _do_movement_pass(MovementPass.SNAP, delta)
			if snap_pass.hit:
				did_movement_snap = true
				grounded = true
		
	if grounded:
		vertical_velocity = 0.0
		
	if did_movement_snap:
		movement_snapped.emit()
	effective_velocity = (owner_node.global_position - prev_position) / delta
	
func get_stance_height(p_stance: int) -> float:
	# HACK: Change this if we for some reason decide to stop using cylinders
	var cyl := stance_shapes[p_stance] as CylinderShape3D
	assert(cyl)
	return cyl.height
