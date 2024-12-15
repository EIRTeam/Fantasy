## General purpose debug geometry overlay class
extends Node3D

class_name DebugOverlay

static var singleton: DebugOverlay

class Overlay:
	var nodes: Array[Node3D]
	var end_time := 0.0
	func dispose():
		for node in nodes:
			node.queue_free()

	func _init(duration: float) -> void:
		if duration > 0.0:
			end_time = GameWorld.get_singleton().state.game_time + duration

var overlays: Array[Overlay]

@onready var _sphere_mesh: Mesh
@onready var _cylinder_mesh: Mesh
var _debug_overlay_material: ShaderMaterial
var _debug_overlay_material_point: ShaderMaterial

func _ready() -> void:
	var csh := CylinderShape3D.new()
	csh.radius = 1.0
	csh.height = 1.0
	_cylinder_mesh = csh.get_debug_mesh()
	
	var sph := SphereShape3D.new()
	sph.radius = 1.0
	_sphere_mesh = sph.get_debug_mesh()
	
	
	_debug_overlay_material = ShaderMaterial.new()
	_debug_overlay_material.shader = preload("res://scripts/debug_overlay/debug_overlay_shader.gdshader")
	_debug_overlay_material_point = ShaderMaterial.new()
	_debug_overlay_material_point.shader = preload("res://scripts/debug_overlay/debug_overlay_shader_point.gdshader")
	name = "DebugOverlay"
	

func advance():
	for i in range(overlays.size()-1, -1, -1):
		var game_time := GameWorld.get_singleton().state.game_time
		if game_time >= overlays[i].end_time:
			overlays[i].dispose()
			overlays.remove_at(i)

func _register_overlay(overlay: Overlay):
	for node in overlay.nodes:
		add_child(node)
	overlays.push_back(overlay)

func _init() -> void:
	singleton = self

static func _create_mesh_instance(mesh: Mesh, color: Color, depth_test := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_surface_override_material(0, singleton._debug_overlay_material)
	mi.set_instance_shader_parameter(&"color", color)
	if not depth_test:
		mi.sorting_offset = 1000000.0
	return mi

static func sphere(center: Vector3, radius: float, color: Color, depth_test := true, duration: float = 0.0):
	if not singleton:
		return
	var overlay := Overlay.new(duration)
	var mi := _create_mesh_instance(singleton._sphere_mesh, color, depth_test)
	mi.transform = Transform3D.IDENTITY.scaled(Vector3.ONE * radius)
	mi.position = center
	overlay.nodes.push_back(mi)
	singleton._register_overlay(overlay)
	
static func line(from: Vector3, to: Vector3, color: Color, depth_test := true, duration := 0.0):
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	
	var mi := _create_mesh_instance(im, color, depth_test)
	var overlay := Overlay.new(duration)
	overlay.nodes.push_back(mi)
	singleton._register_overlay(overlay)
	
static func cylinder(at: Vector3, height: float, radius: float, color: Color, depth_test := true, duration := 0.0):
	var mi := _create_mesh_instance(singleton._cylinder_mesh, color, depth_test)
	mi.transform = Transform3D(Basis.from_scale(Vector3(radius, height, radius)), at)
	var overlay := Overlay.new(duration)
	overlay.nodes.push_back(mi)
	singleton._register_overlay(overlay)
	
static func horz_arrow(from: Vector3, to: Vector3, width: float, color: Color, depth_test := true, duration := 0.0):
	# Build arrow mesh
	var dir := from.direction_to(to)
	var side := dir.cross(Vector3.UP).normalized()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var shaft_size := width * 0.5
	im.surface_add_vertex(from + side * shaft_size)
	im.surface_add_vertex(to - dir * width + side * shaft_size)
	im.surface_add_vertex(to - dir * width + side * width)
	im.surface_add_vertex(to)
	im.surface_add_vertex(to - dir * width - side * width)
	im.surface_add_vertex(to - dir * width - side * shaft_size)
	im.surface_add_vertex(from - side * shaft_size)
	im.surface_end()
	
	var mi := _create_mesh_instance(im, color, depth_test)
	var overlay := Overlay.new(duration)
	overlay.nodes.push_back(mi)
	singleton._register_overlay(overlay)
	
static func vert_arrow(from: Vector3, to: Vector3, width: float, color: Color, depth_test := true, duration := 0.0):
	# Build arrow mesh
	var dir := from.direction_to(to)
	var side := Vector3.DOWN
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var shaft_size := width * 0.5
	im.surface_add_vertex(from + side * shaft_size)
	im.surface_add_vertex(to - dir * width + side * shaft_size)
	im.surface_add_vertex(to - dir * width + side * width)
	im.surface_add_vertex(to)
	im.surface_add_vertex(to - dir * width - side * width)
	im.surface_add_vertex(to - dir * width - side * shaft_size)
	im.surface_add_vertex(from - side * shaft_size)
	im.surface_end()
	
	var mi := _create_mesh_instance(im, color, depth_test)
	var overlay := Overlay.new(duration)
	overlay.nodes.push_back(mi)
	singleton._register_overlay(overlay)
	
static func path(path_points: PackedVector3Array, draw_points: bool, color: Color, depth_test := true, duration := 0.0):
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in path_points:
		im.surface_add_vertex(p)
	im.surface_end()
	if draw_points:
		im.surface_begin(Mesh.PRIMITIVE_POINTS, singleton._debug_overlay_material_point)
		for p in path_points:
			im.surface_add_vertex(p)
		im.surface_end()
	
	var mi := _create_mesh_instance(im, color, depth_test)
	var overlay := Overlay.new(duration)
	overlay.nodes.push_back(mi)
	singleton._register_overlay(overlay)

static func cone_angle(from: Vector3, to: Vector3, angle: float, color: Color, depth_test := true, duration := 0.0):
	# Solid section
	var overlay := Overlay.new(duration)
	var cone_length := from.distance_to(to)
	var cone_direction := from.direction_to(to)
	var end_radius := (Vector3.FORWARD * cone_length).rotated(Vector3.RIGHT, angle*0.5).y
	
	var cone_basis := Quaternion(Vector3.DOWN, from.direction_to(to))
	var cone_position := from + cone_direction * cone_length*0.5
	
	if color.a > 0.0:
		var cone_shape := CylinderMesh.new()
		cone_shape.top_radius = 0.0
		cone_shape.height = cone_length
		cone_shape.bottom_radius = end_radius
		
		var mi_solid := _create_mesh_instance(cone_shape, color, depth_test)
		mi_solid.basis = cone_basis
		mi_solid.position = cone_position
		overlay.nodes.push_back(mi_solid)
		
	# Non-solid part
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	const RES := 64
	var right := Vector3.RIGHT if cone_direction == Vector3.UP or cone_direction == Vector3.DOWN else cone_direction.cross(Vector3.UP).normalized()
	right *= end_radius 
	for i in range(RES):
		var top_angle := (i / float(RES)) * TAU
		var top_angle_2 := ((i+1) / float(RES)) * TAU
		im.surface_add_vertex(to + right.rotated(cone_direction, top_angle))
		im.surface_add_vertex(to + right.rotated(cone_direction, top_angle_2))
	
	for i in range(4):
		var top_angle := (i / 4.0) * TAU
		im.surface_add_vertex(from)
		im.surface_add_vertex(to + right.rotated(cone_direction, top_angle))
	
	im.surface_end()
		
	color.a = 1.0
	var mi := _create_mesh_instance(im, color, true)
	overlay.nodes.push_back(mi)
	singleton._register_overlay(overlay)
