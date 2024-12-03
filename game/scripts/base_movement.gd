extends PhysicsBody3D

class_name HBBaseMovement

## Emitted when snapped, either when going up slopes/stairs or going down slopes
signal movement_snapped

var desired_velocity := Vector3()

const GRAVITY_ACCEL := 1.0
const MAX_VERTICAL_SPEED := 10.0
const ACCELERATION := 100.0
const MAX_MOVE_SPEED := 5.0
const MAX_CROUCHING_MOVE_SPEED := 3.0
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

class MovementPassResult:
	var hit := false
	var movement_snapped := false

enum Stance {
	STANDING,
	CROUCHING
}

@export var standing_collision_shape: CollisionShape3D
@export var crouching_collision_shape: CollisionShape3D

@onready var stance_collision_shapes: Dictionary[Stance, CollisionShape3D] = {
	Stance.STANDING: standing_collision_shape,
	Stance.CROUCHING: crouching_collision_shape
}

@export var graphics_node: Node3D
@export var ghost_physics_body: Node3D

var stance := Stance.STANDING:
	set(val):
		stance = val
		for i_stance in stance_collision_shapes:
			stance_collision_shapes[i_stance].disabled = i_stance != stance
		# We'll eventually get better graphics, I promise
		# TODO: Remove this when and if the game gets actual graphics
		graphics_node.position = Vector3.ZERO
		graphics_node.scale = Vector3.ONE
		if stance == Stance.CROUCHING:
			graphics_node.scale.y = 0.625
			graphics_node.position.y = -0.3

func get_desired_velocity() -> Vector3:
	return Vector3()

func _plane_project(normal: Vector3, velocity: Vector3):
	var out := Plane(normal).project(velocity).normalized()
	out *= velocity.length()
	return out

class StairSnapResult:
	var success := false
	var resulting_position := Vector3()

func _try_snap_up_stair(movement_direction: Vector3, starting_trf: Transform3D) -> StairSnapResult:
	var out := StairSnapResult.new()
	# Try casting up
	var stair_up_collision := KinematicCollision3D.new()
	if test_move(starting_trf, Vector3(0.0, MAX_STEP_HEIGHT, 0.0), stair_up_collision):
		return out
	# Now let's try casting to our new stair location
	var stair_down_collision := KinematicCollision3D.new()
	starting_trf.origin += Vector3(0.0, MAX_STEP_HEIGHT, 0.0)
	if not test_move(starting_trf, Vector3(0.0, -MAX_STEP_HEIGHT, 0.0) + movement_direction * MIN_STEP_DEPTH, stair_down_collision):
		return out
	
	# Finally, check if the surface we hit on the way down is walkable
	if stair_down_collision.get_angle() > deg_to_rad(MAX_SLOPE_ANGLE):
		return out
	out.resulting_position = starting_trf.origin + stair_down_collision.get_travel()
	out.success = true
	return out
	
## Movement iteration, returns true if we are done
func _move_iter(starting_trf: Transform3D, motion: Vector3, desired_movement_direction: Vector3, movement_pass: MovementPass) -> MovementIterationResult:
	const MOTION_MARGIN := 0.001
	var out_result := MovementIterationResult.new()
	var shape_cast_result := KinematicCollision3D.new()
	out_result.new_transform = starting_trf
	if not test_move(starting_trf, motion, shape_cast_result, MOTION_MARGIN):
		out_result.done = true
		out_result.new_transform.origin += motion
		return out_result
	out_result.hit = true
	
	var snapped_to_surface := shape_cast_result.get_travel()
	var remainder := shape_cast_result.get_remainder()
	
	# We travelled a bit too little, so let's pretend we didn't travel at all
	if snapped_to_surface.length() < MOTION_MARGIN:
		snapped_to_surface = Vector3.ZERO
	
	out_result.new_transform.origin = starting_trf.origin + snapped_to_surface
	
	var cast_normal := shape_cast_result.get_normal()
	
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
				var lateral_normal := shape_cast_result.get_normal()
				lateral_normal.y = 0.0
				lateral_normal = lateral_normal.normalized()
				var lateral_desired_movement := desired_movement_direction
				lateral_desired_movement.y = 0.0
				lateral_desired_movement = lateral_desired_movement.normalized()
				var wall_move_scale := 1.0 - lateral_normal.dot(-lateral_desired_movement)
				remainder = _plane_project(lateral_normal, remainder) * wall_move_scale
		
	out_result.remaining_velocity = remainder
	
	return out_result

func _ready() -> void:
	if ghost_physics_body:
		ghost_physics_body.add_collision_exception_with(self)

func _lateral_pass():
	pass
	
func get_max_move_speed() -> float:
	match stance:
		Stance.CROUCHING:
			return MAX_CROUCHING_MOVE_SPEED
	return MAX_MOVE_SPEED
	
func _do_movement_pass(movement_pass: MovementPass, delta: float) -> MovementPassResult:
	var current_transform := global_transform
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
		current_transform = iter_result.new_transform
		remaining_velocity = iter_result.remaining_velocity
		result.movement_snapped = iter_result.movement_snapped if iter_result.movement_snapped else result.movement_snapped
		result.hit = iter_result.hit if iter_result.hit else result.hit
		if iter_result.done:
			break
	if movement_pass != MovementPass.SNAP or result.hit:
		# SNAP pass doesn't apply the new transform unless we actually snapped
		global_transform = current_transform
	return result

func try_change_stance(p_new_stance: Stance) -> bool:
	var shape := stance_collision_shapes[p_new_stance].shape
	var inters := PhysicsShapeQueryParameters3D.new()
	inters.transform = global_transform
	# We need this, otherwise stance change is sometimes rejected for some reason...
	inters.transform.origin += Vector3(0.0, 0.01, 0.0)
	inters.collision_mask = HBPhysicsLayers.LAYER_WORLDSPAWN
	inters.shape_rid = stance_collision_shapes[p_new_stance].shape.get_rid()
	
	var intersections := get_world_3d().direct_space_state.intersect_shape(inters, 1)
	var can_change_stance := intersections.size() == 0
	if can_change_stance:
		stance = p_new_stance
	else:
		print("REJECT STANCE CHANGE!", intersections)
	return can_change_stance
func advance(delta: float) -> void:
	var prev_position := global_position
	
	var lateral_pass := _do_movement_pass(MovementPass.LATERAL, delta)
	var gravity_pass := _do_movement_pass(MovementPass.GRAVITY, delta)
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
	if ghost_physics_body:
		ghost_physics_body.global_position = global_position
	effective_velocity = (global_position - prev_position) / delta
	
