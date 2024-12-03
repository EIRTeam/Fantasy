class_name RotationInertializer

var rotation_velocity := 0.0
var rotation_offset_angle := 0.0
var rotation_offset_axis := Vector3.ZERO
var transition_duration := 0.0

static func create(prev: Quaternion, current: Quaternion, p_target: Quaternion, p_duration: float, p_delta: float) -> RotationInertializer:
	if current.angle_to(p_target) < deg_to_rad(0.05):
		return null

	var inertializer := RotationInertializer.new()

	var q_current: Quaternion = p_target.inverse() * current
	q_current = q_current.normalized()
	var q_prev: Quaternion = p_target.inverse() * prev
	var x0_axis: Vector3 = q_current.get_axis()
	var x0_angle: float = q_current.get_angle()

	x0_axis = x0_axis.normalized()

	# Ensure that rotations are the shortest possible
	if x0_angle > PI:
		x0_angle = 2.0 * PI - x0_angle
		x0_axis = -x0_axis

	var q_x_y_z: Vector3 = Vector3(q_prev.x, q_prev.y, q_prev.z)
	var q_x_m_1: float = 2.0 * atan(q_x_y_z.dot(x0_axis) / q_prev.w)
	inertializer.rotation_velocity = min((x0_angle - q_x_m_1) / p_delta, 0.0)
	inertializer.rotation_offset_angle = x0_angle
	inertializer.rotation_offset_axis = x0_axis
	inertializer.transition_duration = p_duration

	return inertializer
