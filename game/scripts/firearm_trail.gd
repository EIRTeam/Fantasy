extends MeshInstance3D

class_name FirearmTrail

var from: Vector3
var to: Vector3
var velocity: float
var direction: Vector3
var hit_normal: Vector3
var distance := 0.0
var time := 0.0

@onready var debug := HBDebugDraw.new()

func _ready() -> void:
	get_tree().root.add_child(debug)
	get_tree().create_timer(1.0).timeout.connect(debug.queue_free)
func initialize(_from: Vector3, _to: Vector3, _hit_normal: Vector3, _velocity: float):
	from = _from
	to = _to
	velocity = _velocity
	distance = from.distance_to(to)
	direction = from.direction_to(to)
	hit_normal = _hit_normal
	global_position = from
	top_level = true
	_update_rotation()
	debug.clear()
	var sph := SphereShape3D.new()
	sph.radius = 0.1
	debug.draw_shape(sph, to, Color.BLUE)

func _update_rotation():
	var base_rot := Quaternion(Vector3.UP, direction)
	global_basis = base_rot
func _process(delta: float) -> void:
	time += delta
	var progress := (time * velocity) / distance
	global_position = from + direction * progress * distance
	
	if progress >= 1.0:
		const BULLET_HIT_SCENE := preload("res://scenes/vfx/bullet_hit.tscn")
		var bh := BULLET_HIT_SCENE.instantiate() as Node3D
		get_parent().add_child(bh)
		bh.top_level = true
		bh.global_position = to
		bh.global_basis = Quaternion(Vector3.FORWARD, hit_normal)
		bh.emit()
		queue_free()
	
	_update_rotation()
