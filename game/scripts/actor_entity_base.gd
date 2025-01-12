extends Node3D

class_name HBActorEntityBase

var movement: HBBaseMovement
@export var model: HBBipedModel
@export var movement_settings: HBMovementSettings = preload("res://data/movement_settings_default.tres")
var animation: BipedAnimationBase
var aiming := false
var aiming_direction: Vector3

func _create_movement() -> HBBaseMovement:
	return HBBaseMovement.new()

func initialize():
	assert(model)
	assert(movement_settings)
	movement = _create_movement()
	var heights := movement_settings.stance_heights
	movement.initialize(movement_settings.radius, heights, self)
	animation = BipedAnimationBase.new()
	animation.initialize(model)

func _get_animation_locomotion_vector() -> Vector2:
	if movement.effective_velocity.length_squared() > 0.0:
		var model_forward := model.global_basis * Vector3.MODEL_FRONT
		var locomotion_magnitude := movement.effective_velocity.length()
		if locomotion_magnitude < movement_settings.walk_movement_speed:
			locomotion_magnitude = inverse_lerp(0.0, movement_settings.walk_movement_speed, locomotion_magnitude) * 0.5
		else:
			locomotion_magnitude = 0.5 + inverse_lerp(movement_settings.walk_movement_speed, movement_settings.max_movement_speed, locomotion_magnitude) * 0.5
		var effective_vel_norm := movement.effective_velocity / movement_settings.max_movement_speed
		var local := Quaternion(Vector3.FORWARD, model_forward).inverse() * effective_vel_norm
		return Vector2(local.x, local.z)
	return Vector2()

func _get_animation_locomotion_state() -> BipedAnimationBase.LocomotionState:
	var locomotion_state := animation.locomotion_state
	if movement.current_stance_idx == HBBaseMovement.Stance.STANDING:
		if aiming:
			locomotion_state = BipedAnimationBase.LocomotionState.STANDING_STRAFING
		else:
			locomotion_state = BipedAnimationBase.LocomotionState.STANDING
	elif movement.current_stance_idx == HBBaseMovement.Stance.CROUCHING:
		if aiming:
			locomotion_state = BipedAnimationBase.LocomotionState.CROUCHING_STRAFING
		else:
			locomotion_state = BipedAnimationBase.LocomotionState.CROUCHING
	return locomotion_state

func _update_animation_states():
	animation.locomotion_state = _get_animation_locomotion_state()
	animation.upper_body_state = BipedAnimationBase.UpperBodyState.RIFLE_AIM if aiming else BipedAnimationBase.UpperBodyState.IDLE

func _get_facing_direction() -> Vector3:
	if aiming:
		var normal_planar := aiming_direction
		normal_planar.y = 0.0
		normal_planar = normal_planar.normalized()
		if normal_planar.is_normalized():
			return normal_planar
		else:
			return Vector3.ZERO
	var effective_vel_norm := movement.effective_velocity
	effective_vel_norm.y = 0.0
	if effective_vel_norm.length() > 0.1:
		effective_vel_norm = effective_vel_norm.normalized()
		if effective_vel_norm.is_normalized():
			return effective_vel_norm
	return Vector3.ZERO

func advance(delta: float):
	movement.advance(delta)
	var facing_dir := _get_facing_direction()
	if facing_dir.is_normalized():
		model.global_basis = Quaternion(Vector3.MODEL_FRONT, facing_dir)
	animation.locomotion_vector = _get_animation_locomotion_vector()
