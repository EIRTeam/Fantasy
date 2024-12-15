extends Node

class_name HearingDebug

static var singleton: HearingDebug

var material: StandardMaterial3D
var unit_sphere: Mesh
var unit_sphere_shell: Mesh

static var hearing_debug_enabled_cvar := CVar.create(&"hearing_debug", TYPE_BOOL, true, "Draws noise emission events")

func _init() -> void:
	singleton = self
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child.call_deferred(self)
	material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var unit_sphere_shape = SphereShape3D.new()
	unit_sphere_shape.radius = 1.0
	unit_sphere = unit_sphere_shape.get_debug_mesh()
	unit_sphere_shell = SphereMesh.new()
	unit_sphere_shell.height = 2.0
	unit_sphere_shell.radius = 1.0

static func get_singleton() -> HearingDebug:
	# TODO: Don't lazy initialize this...
	if not singleton:
		HearingDebug.new()
	return singleton

func noise_event_emitted(radius: float, location: Vector3):
	if not hearing_debug_enabled_cvar.get_bool():
		return
	var mi_lines := MeshInstance3D.new()
	mi_lines.mesh = unit_sphere
	mi_lines.scale = Vector3.ONE * radius
	mi_lines.set_surface_override_material(0, material)
	add_child(mi_lines)
	mi_lines.position = location
	mi_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var mi_shell := MeshInstance3D.new()
	mi_shell.mesh = unit_sphere_shell
	mi_shell.scale = Vector3.ONE * radius
	mi_shell.set_surface_override_material(0, material)
	add_child(mi_shell)
	mi_shell.position = location
	mi_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var t := create_tween()
	t.tween_property(mi_lines, "transparency", 1.0, 0.75).from(0.0)
	t.parallel().tween_property(mi_shell, "transparency", 1.0, 0.75).from(0.5)
	t.tween_callback(mi_lines.queue_free)
	t.tween_callback(mi_shell.queue_free)
