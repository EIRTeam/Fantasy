class_name PhysicsImpactDamage

## Impulse -> Damage mapping
static var npc_damage_impulse_table: Dictionary[float, float] = {
	350: 5,
	450: 10,
	600: 20,
	750: 50,
	1000: 100,
	2000: 500
}

static var npc_damage_table := ImpactDamageTable.new(
	npc_damage_impulse_table,
	2.0*2.0,
	2.0
)

class ImpactDamageTable:
	var linear_table: Dictionary[float, float]
	
	var min_linear_vel_squared := 2.0*2.0
	var min_mass := 2.0
	
	func _init(_linear_table: Dictionary[float, float], _min_linear_vel_squared: float, _min_mass: float):
		linear_table = _linear_table
		min_linear_vel_squared = _min_linear_vel_squared
		min_mass = _min_mass
	
static func calculate_damage(impulse: float) -> float:
	var damages := npc_damage_table.linear_table.keys()
	var i := damages.bsearch(impulse)-1
	if i != -1:
		return npc_damage_table.linear_table[damages[i]]
	return 0.0
