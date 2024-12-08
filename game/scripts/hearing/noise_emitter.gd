extends Area3D

class_name HBNoiseEmitter

var collision_shape: CollisionShape3D
var sphere_shape := SphereShape3D.new()
var debug_mesh: MeshInstance3D

var radius := 0.0: set = _set_radius
var one_shot := false
var disabled := false:
	set(val):
		disabled = val
		if is_inside_tree():
			collision_shape.disabled = disabled
			if debug_mesh:
				debug_mesh.visible = not disabled

func _set_radius(p_radius: float):
	radius = p_radius

func _init(_radius := 1.0, _one_shot := false) -> void:
	radius = _radius
	collision_layer = HBPhysicsLayers.LAYER_HEARING
	collision_mask = 0
	one_shot = _one_shot

func _ready() -> void:
	var use_debug: bool = ProjectSettings.get_setting(&"fantasy/hearing_debug", false)
	if use_debug:
		debug_mesh = MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = radius
		sphere_mesh.height = radius*2.0
		debug_mesh.mesh = sphere_mesh
		add_child(debug_mesh)
		debug_mesh.scale = Vector3.ONE * radius
		
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color.RED
		sm.albedo_color.a = 0.25
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere_mesh.material = sm
	
	sphere_shape.radius = radius
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = sphere_shape
	add_child(collision_shape)
	if one_shot:
		# Let it be detected for a few frames, and then die, a bit HACK-y but eh...
		await get_tree().create_timer(0.2).timeout
		queue_free()
