extends SkeletonModifier3D

class_name SkeletonModifierHipRotator

@export var target_rotation_degrees: Vector3
@export var global_space_rot: Vector3

func _process_modification() -> void:
	var skel := get_skeleton()
	if not skel:
		return
	var bone := skel.find_bone("Spine")
	var global_pose := skel.get_bone_global_pose(bone)
	var global_add_rot := Quaternion.from_euler(global_space_rot / (180.0/PI))
	global_pose.basis = Basis(global_add_rot * Quaternion.from_euler(target_rotation_degrees / (180.0/PI)))
	skel.set_bone_global_pose(bone, global_pose)
	
	var bone_head := skel.find_bone("Head")
	var head := skel.get_bone_global_pose(bone_head).origin
	DebugOverlay.vert_arrow(head, head + Vector3.MODEL_FRONT * 0.4, 0.15, Color.GREEN)
	
