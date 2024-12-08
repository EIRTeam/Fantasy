extends Control

class_name Crosshair

const CROSSHAIR_LINE_WIDTH = 2.0
const CROSSHAIR_LINE_LENGTH = 5.0

@export_range(0, PI, 0.001, "radians_as_degrees") var spread_angle := deg_to_rad(1):
	set(val):
		spread_angle = val
		queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	var vertical_fov := cam.fov
	var height := get_viewport_rect().size.y
	var pixels_per_rad := height / deg_to_rad(vertical_fov)
	var diameter := spread_angle * pixels_per_rad
	var radius := diameter * 0.5
	draw_circle(Vector2.ZERO, diameter * 0.5, Color.GREEN, false)
	draw_line(Vector2(radius, 0.0), Vector2(radius, 0.0) + Vector2(CROSSHAIR_LINE_LENGTH, 0.0), Color.GREEN, CROSSHAIR_LINE_WIDTH)
	draw_line(Vector2(-radius, 0.0), Vector2(-radius, 0.0) - Vector2(CROSSHAIR_LINE_LENGTH, 0.0), Color.GREEN, CROSSHAIR_LINE_WIDTH)
	draw_line(Vector2(0.0, radius), Vector2(0.0, radius) + Vector2(0.0, CROSSHAIR_LINE_LENGTH), Color.GREEN, CROSSHAIR_LINE_WIDTH)
	draw_line(Vector2(0.0, -radius), Vector2(0.0, -radius) - Vector2(0.0, CROSSHAIR_LINE_LENGTH), Color.GREEN, CROSSHAIR_LINE_WIDTH)
	
