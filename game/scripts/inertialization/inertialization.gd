class_name Inertialization

static func inertialize(p_x0: float, p_v0: float, p_blend_time: float, p_t: float) -> float:
	if p_v0 != 0.0:
		var blend_time_1 := -5.0 * (p_x0 / p_v0)
		if blend_time_1 > 0:
			p_blend_time = min(blend_time_1, p_blend_time);
			p_t = min(p_blend_time, p_t);

	var bt_2: float = p_blend_time * p_blend_time;
	var bt_3: float = bt_2 * p_blend_time;
	var bt_4: float = bt_3 * p_blend_time;
	var bt_5: float = bt_4 * p_blend_time;
	var accel: float = max((-8.0 * p_v0 * p_blend_time - 20.0 * p_x0) / bt_2, 0.0)
	var A: float = -((accel * bt_2 + 6.0 * p_v0 * p_blend_time + 12.0 * p_x0) / (2.0 * bt_5))
	var B: float = (3.0 * accel * bt_2 + 16.0 * p_v0 * p_blend_time + 30.0 * p_x0) / (2.0 * bt_4)
	var C: float = -((3.0 * accel * bt_2 + 12.0 * p_v0 * p_blend_time + 20.0 * p_x0) / (2.0 * bt_3))
	
	var t_2 := p_t * p_t
	var t_3 := t_2 * p_t
	var t_4 := t_3 * p_t
	var t_5 := t_4 * p_t

	return A * t_5 + B * t_4 + C * t_3 + (accel * 0.5) * t_2  + p_v0 * p_t + p_x0
