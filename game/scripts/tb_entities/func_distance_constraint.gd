@tool
extends Node3D

@export var target_a_node_path: NodePath
@export var target_b_node_path: NodePath

@export var global_attachment_location_b: Vector3
@export var elasticity := 100.0

var local_attachment_location_a := Vector3()
var local_attachment_location_b := Vector3()

var node_a: PhysicsBody3D
var node_b: PhysicsBody3D
var max_distance := 0.0

func _get(property: StringName) -> Variant:
	if property in [&"target_a", &"target_b", &"target_attachment_b"]:
		return ""
	return null

func _set_attachment_b(attachment_name: String):
	var node := get_node(NodePath("../" + attachment_name)) as Node3D
	global_attachment_location_b = node.global_position

func _set(property: StringName, value: Variant) -> bool:
	if property in [&"target_a", &"target_b", &"target_attachment_b"]:
		if property == &"target_attachment_b":
			_set_attachment_b.call_deferred(value)
			return true
		set_deferred(&"target_a_node_path" if property == &"target_a" else &"target_b_node_path", NodePath("../" + value))
		return true
	return false

func _ready() -> void:
	set_physics_process(!Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	
	node_a = get_node(target_a_node_path)
	node_b = get_node(target_b_node_path)
	
	assert(node_a, "Node A of distance constraint is missing!")
	assert(node_b, "Node B of distance constraint is missing!")
	
	local_attachment_location_a = node_a.global_transform.affine_inverse() * global_position
	local_attachment_location_b = node_b.global_transform.affine_inverse() * global_attachment_location_b
	
	max_distance = global_position.distance_to(global_attachment_location_b)
func _physics_process(delta: float) -> void:
	var location_a := node_a.global_transform * local_attachment_location_a
	var location_b := node_b.global_transform * local_attachment_location_b
	var diff := location_a.distance_to(location_b)
	if diff > max_distance:
		var a_to_b := location_a.direction_to(location_b)
		var a_force_point := location_a - node_a.global_position
		var b_force_point := location_b - node_b.global_position
		if node_a is RigidBody3D:
			node_a.apply_force(a_to_b * elasticity, a_force_point)
		if node_b is RigidBody3D:
			node_b.apply_force(-a_to_b * elasticity, b_force_point)
