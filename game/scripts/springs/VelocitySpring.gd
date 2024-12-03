class_name VelocitySpring

var velocity: Vector2
var acceleration: Vector2
var halflife := 0.1

func halflife_to_damping(p_halflife: float, eps := 1e-5):
	return (4.0 * 0.69314718056) / (p_halflife + eps)

func fast_negexp(x: float) -> float:
	return 1.0 / (1.0 + x + 0.48*x*x + 0.235*x*x*x)

func advance(target: Vector2, delta: float):
	for i in range(2):
		var out := spring_character_update(velocity[i], acceleration[i], target[i], halflife, delta)
		velocity[i] = out[0]
		acceleration[i] = out[1]
func spring_character_update(
	v: float,
	a: float,
	v_goal: float,
	p_halflife: float,
	dt: float) -> PackedFloat32Array:
		var y: float = halflife_to_damping(p_halflife) / 2.0;
		var j0: float = v - v_goal;
		var j1: float = a + j0*y;
		var eydt: float = fast_negexp(y*dt);

		v = eydt*(j0 + j1*dt) + v_goal;
		a = eydt*(a - j1*y*dt);
		return PackedFloat32Array([v, a])
