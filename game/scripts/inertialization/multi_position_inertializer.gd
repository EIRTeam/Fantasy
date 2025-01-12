class_name MultiPositionInertializer

enum InertFloatParams {
	A,
	B,
	C,
	X0,
	X0V_X,
	X0V_Y,
	X0V_Z,
	A0,
	V0,
	T1,
	SKIP,
	PARAM_MAX
}

var float_params: PackedFloat32Array

var current_time := 0.0
var max_blend_time := 0.0
var ct2 := 0.0
var ct3 := 0.0
var ct4 := 0.0
var ct5 := 0.0

func inertialize(prev: PackedVector3Array, current: PackedVector3Array, next: PackedVector3Array, delta: float, blend_time: float):
	if not prev.size() == current.size() or not prev.size() == next.size():
		return
	current_time = 0.0
	max_blend_time = 0.0
	float_params.resize(prev.size() * InertFloatParams.PARAM_MAX)
	for i in range(prev.size()):
		var params_idx := i * InertFloatParams.PARAM_MAX
		var x0v := current[i] - next[i]
		var x_minus1v := prev[i] - next[i]
		
		var x0 := sqrt(x0v.dot(x0v))
		if is_zero_approx(x0):
			# can be consider there's no change at all
			float_params[params_idx+InertFloatParams.SKIP] = 1.0
			continue
		else:
			float_params[params_idx+InertFloatParams.SKIP] = 0.0
		var x_minus1 := x_minus1v.dot(x0v.normalized())
		# compute v0 and a0
		# note.
		# if x0 >= 0 then v0 should be < 0 and a0 should be > 0
		# if x0 < 0 then v0 should be > 0 and a0 should be < 0
		# if this is not the case, just clamp v0 or a0

		# v0 = (x0 - x_minus1) / dt
		var v0 := (x0 - x_minus1) / delta
		var t1 := blend_time
		if ((x0 > 0.0 && v0 < 0.0) || (x0 < 0 && v0 > 0.0)):
			# t1 = min(t1, -5 * x0/v0)
			t1 = min(t1, -5.0 * x0 / v0);
		max_blend_time = max(t1, max_blend_time)
		var a0 := (-8.0 * v0 * t1 - 20.0 * x0) / (t1 * t1)
		if (x0 > 0.0):
			if (v0 > 0.0):
				v0 = 0.0
			if (a0 < 0.0):
				a0 = 0.0
		else:
			if (v0 < 0.0):
				v0 = 0.0
			if (a0 > 0.0):
				a0 = 0.0
		# A = - (a0 * t1^2 + 6 * v0 * t1 + 12 * x0) / (2 * t1^5)
		var A := -(a0 * t1 * t1 + 6 * v0 * t1 + 12 * x0) / (2 * t1 * t1 * t1 * t1 * t1);
		# B = (3 * a0 * t1^2 + 16 * v0 * t1 + 30 * x0) / (2 * t1^4)
		var B := (3 * a0 * t1 * t1 + 16 * v0 * t1 + 30 * x0) / (2 * t1 * t1 * t1 * t1);
		# C = - (3 * a0 * t1^2 + 12 * v0 * t1 + 20 * x0) / (2 * t1^3)
		var C := -(3 * a0 * t1 * t1 + 12 * v0 * t1 + 20 * x0) / (2 * t1 * t1 * t1);
		float_params[params_idx + InertFloatParams.A] = A
		float_params[params_idx + InertFloatParams.B] = B
		float_params[params_idx + InertFloatParams.C] = C
		float_params[params_idx + InertFloatParams.X0] = x0
		float_params[params_idx + InertFloatParams.X0V_X] = x0v.x
		float_params[params_idx + InertFloatParams.X0V_Y] = x0v.y
		float_params[params_idx + InertFloatParams.X0V_Z] = x0v.z
		float_params[params_idx + InertFloatParams.A0] = a0
		float_params[params_idx + InertFloatParams.V0] = v0
		float_params[params_idx + InertFloatParams.T1] = t1

func inertialize_position(idx: int, new_vector: Vector3) -> Vector3:
	var param_idx := InertFloatParams.PARAM_MAX * idx
	if float_params[param_idx + InertFloatParams.SKIP] == 1.0 or current_time > float_params[param_idx + InertFloatParams.T1]:
		return new_vector

	var A := float_params[param_idx + InertFloatParams.A]
	var B := float_params[param_idx + InertFloatParams.B]
	var C := float_params[param_idx + InertFloatParams.C]
	var a0 := float_params[param_idx + InertFloatParams.A0]
	var v0 := float_params[param_idx + InertFloatParams.V0]
	var x0 := float_params[param_idx + InertFloatParams.X0]
	var x0v := Vector3(
		float_params[param_idx + InertFloatParams.X0V_X],
		float_params[param_idx + InertFloatParams.X0V_Y],
		float_params[param_idx + InertFloatParams.X0V_Z]
	)

	var x := A * ct5 \
		+ B * ct4 \
		+ C * ct3 \
		+ 0.5 * a0 * ct2 \
		+ v0 * current_time \
		+ x0

	var dv := x0v.normalized() * x
	return new_vector + dv

func is_done() -> bool:
	return current_time >= max_blend_time
func advance(delta: float):
	current_time += delta
	current_time = min(current_time, max_blend_time)
	ct2 = current_time * current_time
	ct3 = ct2 * current_time
	ct4 = ct3 * current_time
	ct5 = ct4 * current_time
