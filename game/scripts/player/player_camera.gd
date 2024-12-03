extends Node3D

class_name HBPlayerCameraArm


var offset_inertializer: PositionInertializer
var prev_camera_offset := Vector3.ZERO
var camera_offset := BASE_CAMERA_OFFSET
var target_camera_offset := BASE_CAMERA_OFFSET

var position_inertializer: PositionInertializer
var base_tracked_position := Vector3.ZERO
var prev_position := Vector3.ZERO

var fov_inertializer: ScalarInertializer
var prev_camera_fov := 0.0
var target_camera_fov := 0.0

const BASE_DISTANCE := 3.0

var collision_shape := SphereShape3D.new()

const BASE_CAMERA_OFFSET := Vector3(0.5, 0.75, 3.0)
const ADS_CAMERA_OFFSET := Vector3(0.75, 0.75, 2.0)

const BASE_FOV := 75
const KNIFE_CHARGED_FOV := 55

@onready var camera: Camera3D = get_node("%Camera3D")

func calculate_camera_position() -> Vector3:
	return global_transform * camera_offset

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	top_level = true
	prev_position = global_position
	collision_shape.radius = 0.25
	camera.top_level = true
	prev_camera_fov = camera.fov
	target_camera_fov = camera.fov

func _input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * 0.01
		rotation.x = clamp((rotation.x - event.relative.y * 0.01), deg_to_rad(-60), deg_to_rad(60))
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F2:
				inertialize_position()

func inertialize_position():
	position_inertializer = PositionInertializer.create(prev_position, global_position, base_tracked_position, 0.4, get_process_delta_time())

func inertialize_fov():
	fov_inertializer = ScalarInertializer.create(prev_camera_fov, camera.fov, target_camera_fov, 0.75, get_process_delta_time())

func inertialize_offset():
	offset_inertializer = PositionInertializer.create(prev_camera_offset, camera_offset, target_camera_offset, 0.75, get_process_delta_time())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	prev_camera_offset = camera_offset
	prev_position = global_position
	prev_camera_fov = camera.fov
	
	global_position = base_tracked_position
	
	if position_inertializer:
		global_position = base_tracked_position + position_inertializer.advance(delta)
		if position_inertializer.is_done():
			position_inertializer = null

	if offset_inertializer:
		camera_offset = target_camera_offset + offset_inertializer.advance(delta)
		if offset_inertializer.is_done():
			offset_inertializer = null
	else:
		camera_offset = target_camera_offset
	
	if fov_inertializer:
		var offset := fov_inertializer.advance(delta)
		camera.fov = target_camera_fov + offset
		if fov_inertializer.is_done():
			fov_inertializer = null
	else:
		camera.fov = target_camera_fov
	
	# Apply camera offset
	camera.global_position = calculate_camera_position()
	camera.global_basis = global_basis
	
	var shape_cast := PhysicsShapeQueryParameters3D.new()
	shape_cast.transform.origin = global_position
	shape_cast.motion = global_basis * (camera_offset.normalized() * BASE_DISTANCE)
	shape_cast.shape = collision_shape
	shape_cast.collision_mask = 0b1
	
	var dss := get_world_3d().direct_space_state
	var shape_cast_out := dss.cast_motion(shape_cast)
	camera.global_position = shape_cast.transform.origin + shape_cast.motion * shape_cast_out[0]
