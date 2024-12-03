extends Node3D

class_name HBDebugDraw

var im := ImmediateMesh.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	top_level = true
	global_transform = Transform3D()
	var mi := MeshInstance3D.new()
	add_child(mi)
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat

func clear():
	im.clear_surfaces()

func draw_line(from: Vector3, to: Vector3, color := Color.RED):
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
