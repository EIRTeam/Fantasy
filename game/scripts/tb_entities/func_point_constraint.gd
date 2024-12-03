@tool
extends JoltPinJoint3D

func _set(property: StringName, value: Variant) -> bool:
	if property in [&"target_a", &"target_b"]:
		set_deferred(&"node_a" if property == &"target_a" else &"node_b", NodePath("../" + value))
		return true
	return false

func _get(property: StringName) -> Variant:
	if property in [&"target_a", &"target_b"]:
		return ""
	return null
