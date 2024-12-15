extends Node3D

class_name HBDebugDraw

class DebugLayer:
	var mi: MeshInstance3D
	var im: ImmediateMesh
	var shape_mis: Array[MeshInstance3D]

var debug_layers: Dictionary[StringName, DebugLayer]

const DEFAULT_DEBUG_LAYER := &"default"
var debug_mat: StandardMaterial3D
var point_debug_mat: StandardMaterial3D

func create_debug_layer(layer_name: StringName):
	assert(!debug_layers.has(layer_name))
	var dl := DebugLayer.new()
	dl.im = ImmediateMesh.new()
	dl.mi = MeshInstance3D.new()
	dl.mi.mesh = dl.im
	add_child(dl.mi)
	debug_layers[layer_name] = dl
	
func _ready() -> void:
	top_level = true
	global_transform = Transform3D()
	debug_mat = StandardMaterial3D.new()
	debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_mat.vertex_color_use_as_albedo = true
	
	point_debug_mat = debug_mat.duplicate()
	point_debug_mat.use_point_size = true
	point_debug_mat.point_size = 4.0
	
	create_debug_layer(DEFAULT_DEBUG_LAYER)

func get_debug_layer(layer_name: StringName) -> DebugLayer:
	var dl := debug_layers.get(layer_name, null) as DebugLayer
	assert(dl)
	return dl
func clear(layer_name := DEFAULT_DEBUG_LAYER):
	var layer := get_debug_layer(layer_name)
	layer.im.clear_surfaces()
	for shape in layer.shape_mis:
		shape.queue_free()
	layer.shape_mis.clear()

func draw_line(from: Vector3, to: Vector3, color := Color.RED, layer_name := DEFAULT_DEBUG_LAYER):
	var layer := get_debug_layer(layer_name)
	layer.im.surface_begin(Mesh.PRIMITIVE_LINES, debug_mat)
	layer.im.surface_set_color(color)
	layer.im.surface_add_vertex(from)
	layer.im.surface_add_vertex(to)
	layer.im.surface_end()

func draw_shape(shape: Shape3D, at_position: Vector3, color := Color.RED, layer_name := DEFAULT_DEBUG_LAYER):
	var layer := get_debug_layer(layer_name)
	var debug_mesh := shape.get_debug_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = debug_mesh
	mi.position = at_position
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = color
	mi.set_surface_override_material(0, sm)
	add_child(mi)
	layer.shape_mis.push_back(mi)

func draw_path(path: PackedVector3Array, draw_points := true, color := Color.RED, layer_name := DEFAULT_DEBUG_LAYER):
	var layer := get_debug_layer(layer_name)
	layer.im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, debug_mat)
	layer.im.surface_set_color(color)
	for p in path:
		layer.im.surface_add_vertex(p)
	layer.im.surface_end()
	if draw_points:
		layer.im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, point_debug_mat)
		layer.im.surface_set_color(color)
		for p in path:
			layer.im.surface_add_vertex(p)
		layer.im.surface_end()
