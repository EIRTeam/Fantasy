@tool
extends Marker3D

class_name HBPathCorner

@export var first := false
@export var path_points: Array[PathCornerPointInformation]
@export var wait_time := 0.0

func _get(property: StringName) -> Variant:
	if property == &"target":
		return ""
	return null

func _store_path():
	var our_path_point := PathCornerPointInformation.new()
	our_path_point.position = global_position
	our_path_point.wait_time = wait_time
	path_points.push_back(our_path_point)
	var next := get_meta(&"__next_corner", "") as String
	while not next.is_empty():
		var node := get_node("../" + next) as HBPathCorner
		assert(node)
		var path_point := PathCornerPointInformation.new()
		path_point.position = node.global_position
		path_point.wait_time = node.wait_time
		path_points.push_back(path_point)
		next = node.get_meta(&"__next_corner", "")

func _set(property: StringName, value: Variant) -> bool:
	if property == &"target":
		set_meta(&"__next_corner", value)
		if first:
			_store_path.call_deferred()
		return true
	return false
