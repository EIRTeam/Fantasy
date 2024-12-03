extends HBBaseMovement

class_name HBPlayerMovement

var desired_velocity_spring := VelocitySpring.new()

func get_input() -> Vector3:
	var vec_2d := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	return Vector3(vec_2d.x, 0.0, vec_2d.y)

func get_input_transformed() -> Vector3:
	var camera_3d := get_viewport().get_camera_3d()
	var desired_input := get_input()
	var desired_iput_length := desired_input.length()
	var transformed_input := camera_3d.get_camera_transform().basis * desired_input
	transformed_input = Plane(Vector3.UP).project(transformed_input).normalized() * desired_iput_length
	return transformed_input

func get_desired_velocity() -> Vector3:
	return Vector3(desired_velocity_spring.velocity.x, 0.0, desired_velocity_spring.velocity.y)

func advance(delta: float) -> void:
	var desired_input := get_input_transformed()
	var target_desired_velocity := desired_input * get_max_move_speed()
	desired_velocity_spring.advance(Vector2(target_desired_velocity.x, target_desired_velocity.z), delta)
	super.advance(delta)
	
