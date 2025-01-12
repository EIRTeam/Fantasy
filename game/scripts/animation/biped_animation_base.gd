class_name BipedAnimationBase

const LOCOMOTION_TRANSITION_REQUEST_PROPERTY_NAME := &"parameters/LocomotionTransition/transition_request"
const UPPER_BODY_TRANSITION_REQUEST_PROPERTY_NAME := &"parameters/UpperBodyTransition/transition_request"
const UPPER_BODY_BLEND_PARAMETER_PROPERTY_NAME := &"parameters/UpperBodyBlend/blend_amount"
const LOCOMOTION_TIME_SCALE_PROPERTY_NAME := &"parameters/LocomotionTimeScale/scale"

enum LocomotionState {
	STANDING,
	STANDING_STRAFING,
	CROUCHING,
	CROUCHING_STRAFING
}

enum UpperBodyState {
	IDLE,
	IDLE_RIFLE,
	RIFLE_AIM
}

var model: HBBipedModel
var inertializer: InertializationSkeletonModifier3D

var locomotion_state: LocomotionState:
	set(val):
		locomotion_state = val
		model.animation_tree.set(LOCOMOTION_TRANSITION_REQUEST_PROPERTY_NAME, get_transition_name_for_locomotion_state(locomotion_state))
		_update_locomotion_blend_state()
		inertialize()

var upper_body_state: UpperBodyState:
	set(val):
		upper_body_state = val
		model.animation_tree.set(UPPER_BODY_TRANSITION_REQUEST_PROPERTY_NAME, get_transition_name_for_upper_body_state(upper_body_state))
		if upper_body_state in [UpperBodyState.RIFLE_AIM]:
			model.hip_rotator.active = true
			_update_upper_body_blend(1.0)
		else:
			model.hip_rotator.active = false
			_update_upper_body_blend(0.0)
		inertialize()

var aim_direction := Vector3()
var locomotion_vector := Vector2():
	set(val):
		locomotion_vector = val
		_update_locomotion_blend_state()

func get_transition_name_for_upper_body_state(state: UpperBodyState) -> StringName:
	match state:
		UpperBodyState.IDLE:
			return &"Idle"
		UpperBodyState.IDLE_RIFLE:
			return &"IdleRifle"
		UpperBodyState.RIFLE_AIM:
			return &"RifleAim"
	assert(false)
	return &""
func get_transition_name_for_locomotion_state(state: LocomotionState) -> StringName:
	match state:
		LocomotionState.STANDING:
			return &"Standing"
		LocomotionState.STANDING_STRAFING:
			return &"StandingStrafing"
		LocomotionState.CROUCHING:
			return &"Crouching"
		LocomotionState.CROUCHING_STRAFING:
			return &"CrouchingStrafing"
	return &""
func get_current_locomotion_blend_space_name() -> StringName:
	match locomotion_state:
		LocomotionState.STANDING:
			return &"Standing"
		LocomotionState.STANDING_STRAFING:
			return &"StandingStrafing"
		LocomotionState.CROUCHING:
			return &"Crouching"
		LocomotionState.CROUCHING_STRAFING:
			return &"CrouchingStrafing"
	return &""

func _update_upper_body_blend(new_blend: float):
	model.animation_tree.set(UPPER_BODY_BLEND_PARAMETER_PROPERTY_NAME, new_blend)

func _update_locomotion_blend_state():
	var current_space_name := get_current_locomotion_blend_space_name()
	if current_space_name.is_empty():
		return
	var blend_position_property_name := StringName("parameters/" + current_space_name + "/blend_position")
	var current_node: AnimationNode = (model.animation_tree.tree_root as AnimationNodeBlendTree).get_node(current_space_name)
	
	var out_value: Variant
	if current_node is AnimationNodeBlendSpace2D:
		out_value = locomotion_vector
		out_value.y *= -1.0
		model.animation_tree.set(LOCOMOTION_TIME_SCALE_PROPERTY_NAME, 1.0 + locomotion_vector.length())
	elif current_node is AnimationNodeBlendSpace1D:
		out_value = locomotion_vector.length()
		model.animation_tree.set(LOCOMOTION_TIME_SCALE_PROPERTY_NAME, 1.0 + out_value)
	model.animation_tree.set(blend_position_property_name, out_value)
	
func inertialize():
	inertializer.queue_inertialization(0.25)

func initialize(_model: HBBipedModel):
	model = _model
	inertializer = InertializationSkeletonModifier3D.new()
	model.skeleton.add_child(inertializer)
	locomotion_state = LocomotionState.STANDING
	upper_body_state = UpperBodyState.IDLE
