extends TextureProgressBar

class_name HBUIAlertMeter

enum AlertMeterType {
	SUSPICIOUS,
	ALERT
}

@export var type := AlertMeterType.ALERT:
	set(val):
		if type == val:
			return
		type = val
		_update_colors()

func _update_colors():
	match type:
		AlertMeterType.ALERT:
			tint_progress = get_theme_color(&"color_alert", &"HBUIAlertMeter")
		AlertMeterType.SUSPICIOUS:
			tint_progress = get_theme_color(&"color_caution", &"HBUIAlertMeter")

func _ready() -> void:
	_update_colors()
	min_value = 0.0
	max_value = 1.0
	step = 0.0

func _update_placement(cam_origin: Vector3, cam_forward: Vector3, target_position: Vector3):
	var dir_to_target := cam_origin.direction_to(target_position)
	dir_to_target.y = 0.0
	dir_to_target = dir_to_target.normalized()
	if dir_to_target.is_normalized():
		var angle := cam_forward.signed_angle_to(dir_to_target, Vector3.UP)
		var center: Vector2 = get_parent_control().size * 0.5 
		position = center + (Vector2.DOWN * 250.0).rotated(-angle)
		position -= size * 0.5
		pivot_offset = size * 0.5
		rotation = PI - angle
