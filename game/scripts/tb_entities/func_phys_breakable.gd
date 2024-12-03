@tool
extends DestroyableRigidBody

func _get(property: StringName) -> Variant:
	if property.begins_with("on_destroyed/"):
		return ""
	return null

func _connect_up_on_destroyed(target_name: String, target_method: String):
	var child := get_parent().find_child(target_name)
	if child:
		destroyed.connect(child.get(target_method), CONNECT_PERSIST)
func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with("on_destroyed/"):
		var str_value := value as String
		if not str_value.is_empty():
			var split := str_value.split(".")
			var target_name := split[0]
			var target_method := split[1]
			_connect_up_on_destroyed.call_deferred(target_name, target_method)
		return true
	return false
