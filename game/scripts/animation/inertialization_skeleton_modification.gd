extends SkeletonModifier3D

class_name InertializationSkeletonModifier3D

var rotation_inertializer := MultiRotationInertializer.new()
var position_inertializer := MultiPositionInertializer.new()

var is_active := false

var prev_rotations: Array[Quaternion]
var current_rotations: Array[Quaternion]
var next_rotations: Array[Quaternion]

var prev_positions: PackedVector3Array
var current_positions: PackedVector3Array
var next_positions: PackedVector3Array

var inertialization_queued := false
var blend_time := 0.0

func queue_inertialization(_blend_time: float):
	inertialization_queued = true
	blend_time = _blend_time

func _fill_rotation_array(arr: Array[Quaternion]):
	var skel := get_skeleton()
	arr.resize(skel.get_bone_count())
	for i in range(skel.get_bone_count()):
		arr[i] = skel.get_bone_pose_rotation(i)

func _fill_position_array(arr: PackedVector3Array):
	var skel := get_skeleton()
	arr.resize(skel.get_bone_count())
	for i in range(skel.get_bone_count()):
		arr[i] = skel.get_bone_pose_position(i)

func _process_modification() -> void:
	var skel := get_skeleton()
	
	if not skel:
		return
	
	var tmp := prev_rotations
	prev_rotations = current_rotations
	current_rotations = next_rotations
	next_rotations = tmp
	
	var tmp_pos := prev_positions
	prev_positions = current_positions
	current_positions = next_positions
	next_positions = tmp_pos
	
	var delta := get_physics_process_delta_time()
	
	if skel.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
		delta = get_process_delta_time()
	else:
		delta = get_physics_process_delta_time()
	
	if inertialization_queued:
		_fill_rotation_array(next_rotations)
		_fill_position_array(next_positions)
		print(delta, blend_time)
		rotation_inertializer.inertialize(prev_rotations, current_rotations, next_rotations, delta, blend_time)
		position_inertializer.inertialize(prev_positions, current_positions, next_positions, delta, blend_time)
		delta = 0.0
		inertialization_queued = false
		print("QUEUE INERT", rotation_inertializer.max_blend_time)
	rotation_inertializer.advance(delta)
	position_inertializer.advance(delta)
	
	if not rotation_inertializer.is_done():
		for i in range(skel.get_bone_count()):
			skel.set_bone_pose_rotation(i, rotation_inertializer.inertialize_quaternion(i, skel.get_bone_pose_rotation(i)))
	if not position_inertializer.is_done():
		for i in range(skel.get_bone_count()):
			skel.set_bone_pose_position(i, position_inertializer.inertialize_position(i, skel.get_bone_pose_position(i)))
	_fill_rotation_array(next_rotations)
	_fill_position_array(next_positions)
