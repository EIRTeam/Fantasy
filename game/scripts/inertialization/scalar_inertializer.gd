class_name ScalarInertializer

var current_transition_time := 0.0
var scalar_offset := 0.0
var scalar_velocity := 0.0
var transition_duration := 0.0

static func create(p_prev: float, p_current: float, p_target: float, p_duration: float, p_delta: float) -> ScalarInertializer:
	var inertializer := ScalarInertializer.new()

	# Position info
	var x_current: float = p_current - p_target
	inertializer.scalar_velocity = max((p_current - p_prev) / p_delta, 0.0)
	inertializer.scalar_offset = x_current
	inertializer.transition_duration = p_duration
	if inertializer.scalar_velocity != 0.0:
		inertializer.transition_duration = min(p_duration, -5.0 * (x_current / inertializer.scalar_velocity))
	return inertializer

func advance(p_delta: float) -> float:
	current_transition_time += p_delta
	current_transition_time = min(transition_duration, current_transition_time)
	var pos_x: float = Inertialization.inertialize(scalar_offset, scalar_velocity, transition_duration, current_transition_time)
	return pos_x

func is_done():
	return current_transition_time >= transition_duration

func get_offset() -> float:
	return scalar_offset
