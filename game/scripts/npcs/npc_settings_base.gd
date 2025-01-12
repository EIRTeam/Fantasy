extends Resource

class_name HBNPCSettingsBase

@export_range(0, 5.0) var movement_speed := 5.0
@export_range(0, 5.0) var movement_speed_patrol := 2.5
@export_range(0, 100) var vision_range := 20.0
@export_range(0.0, 180.0, 0.001, "radians_as_degrees") var vision_fov := deg_to_rad(65.0)
@export_range(1.0, 100.0, 1.0) var base_health := 100.0
