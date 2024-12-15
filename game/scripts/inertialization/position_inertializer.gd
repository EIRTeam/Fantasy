class_name PositionInertializer

# Kindly borrowed from https://github.com/Ribosome-rbx/Motion-Matching-for-Human-Skeleton/blob/main/src/libs/mom/include/mom/MotionMatching.h
# if only I understood it

var current_transition_time := 0.0
var a0 := 0.0
var x0v := Vector3.ZERO
var A := 0.0
var B := 0.0
var C := 0.0
var t1 := 0.0
var v0 := 0.0
var x0 := 0.0

static func create(p_prev: Vector3, p_current: Vector3, p_target: Vector3, p_t1: float, dt: float) -> PositionInertializer:
	var _x0v := p_current - p_target
	var x_minus1v := p_prev - p_target

	# Frobenius norm (eigen norm())
	var _x0 := sqrt(_x0v.dot(_x0v));
	if (_x0 < 1e-10):
		return null;

	# compute x_minus1
	var x_minus1 := x_minus1v.dot(_x0v.normalized())

	# compute v0 and a0
	# note.
	# if x0 >= 0 then v0 should be < 0 and a0 should be > 0
	# if x0 < 0 then v0 should be > 0 and a0 should be < 0
	# if this is not the case, just clamp v0 or a0

	# v0 = (x0 - x_minus1) / dt
	var _v0 := (_x0 - x_minus1) / dt;

	if ((_x0 > 0 && _v0 < 0) || (_x0 < 0 && _v0 > 0)):
		p_t1 = min(p_t1, -5 * _x0 / _v0);

	# a0 = (-8 * v0 * t1 - 20 * x0) / (t1^2)
	var _a0 := (-8 * _v0 * p_t1 - 20 * _x0) / (p_t1 * p_t1);

	if _x0 > 0:
		if _v0 > 0:
			_v0 = 0;
		if _a0 < 0:
			_a0 = 0;
	else:
		if _v0 < 0:
			_v0 = 0
		if _a0 > 0:
			_a0 = 0;

	# A = - (a0 * t1^2 + 6 * v0 * t1 + 12 * x0) / (2 * t1^5)
	var _A := -(_a0 * p_t1 * p_t1 + 6.0 * _v0 * p_t1 + 12.0 * _x0) / (2.0 * p_t1 * p_t1 * p_t1 * p_t1 * p_t1);
	# B = (3 * a0 * t1^2 + 16 * v0 * t1 + 30 * x0) / (2 * t1^4)
	var _B := (3.0 * _a0 * p_t1 * p_t1 + 16.0 * _v0 * p_t1 + 30.0 * _x0) / (2.0 * p_t1 * p_t1 * p_t1 * p_t1);
	# C = - (3 * a0 * t1^2 + 12 * v0 * t1 + 20 * x0) / (2 * t1^3)
	var _C := -(3.0 * _a0 * p_t1 * p_t1 + 12.0 * _v0 * p_t1 + 20.0 * _x0) / (2.0 * p_t1 * p_t1 * p_t1);

	var info := PositionInertializer.new()
	info.x0v = _x0v;
	info.A = _A;
	info.B = _B;
	info.C = _C;
	info.x0 = _x0;
	info.v0 = _v0;
	info.a0 = _a0;
	info.t1 = p_t1;
	return info;

func advance(p_delta: float) -> Vector3:
	current_transition_time += p_delta
	current_transition_time = min(t1, current_transition_time)
	var t := current_transition_time
	var t2 := t * t
	var t3 := t2 * t
	var t4 := t3 * t
	var t5 := t4 * t
	var x := self.A * t5 \
		+ self.B * t4 \
		+ self.C * t3 \
		+ 0.5 * self.a0 * t2 \
		+ self.v0 * t \
		+ self.x0
	var pos_off: Vector3 = x0v.normalized() * x
	return pos_off

func is_done():
	return current_transition_time >= t1
