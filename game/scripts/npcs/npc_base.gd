@tool
extends RexbotNPCBase

class_name NPCBase

@export var patrol_route: HBPathCorner
@export var patrol_speed := 2.0
@export var vision_range := 20.0
@export var vision_fov := 65.0
var health := 50.0

var target: Vector3
var navigation_active := false
var navigation: NPCNavigation
var vision: NPCVision

class NPCVision:
	var guard: NPCBase
	var visible_entities: Array[Node3D]
	
	func _init(_guard: NPCGuard):
		guard = _guard
	
	func advance():
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = guard.vision_range
		var ray_params := PhysicsShapeQueryParameters3D.new()
		ray_params.collision_mask = HBPhysicsLayers.LAYER_ENTITIES
		ray_params.transform.origin = guard.npc_movement.global_position
		ray_params.shape = sphere_shape
		var cast_result := guard.get_world_3d().direct_space_state.intersect_shape(ray_params)
		
		visible_entities.clear()
		var guard_forward := guard.npc_movement.graphics_node.global_basis * Vector3.FORWARD
		guard.debug_geo.clear()
		guard.debug_geo.draw_line(guard.npc_movement.global_position, guard.npc_movement.global_position + guard_forward, Color.GREEN)
		if cast_result.is_empty():
			return
		for result in cast_result:
			var collider := result.collider as PhysicsBody3D
			var dir_to_entity := guard.npc_movement.global_position.direction_to(result.collider.global_position)
			if guard_forward.angle_to(dir_to_entity) <= deg_to_rad(guard.vision_fov * 0.5):
				var parent := collider.get_parent()
				if parent is HBPlayer:
					visible_entities.push_back(parent)
				else:
					visible_entities.push_back(collider)

class NPCNavigation:
	var npc: NPCBase
	var target_position: Vector3
	const REPATH_RADIUS := 1.0
	const REPATH_RADIUS_2 := REPATH_RADIUS * REPATH_RADIUS
	var last_calculated_target_position := Vector3.ZERO
	var active := false
	var target_movement_speed := 2.0
	
	func begin_navigating_to(point: Vector3, _movement_speed: float):
		target_position = point
		active = true
		var nav_agent := npc.nav_agent
		nav_agent.target_position = point
		nav_agent.max_speed = _movement_speed
		target_movement_speed = _movement_speed
	
	func _init(_npc: NPCBase) -> void:
		npc = _npc
		_npc.nav_agent.velocity_computed.connect(self._apply_navigation_velocity)
	
	func is_navigation_finished() -> bool:
		return npc.nav_agent.is_navigation_finished()
	
	func advance(delta: float):
		var nav_agent := npc.nav_agent
		var next_path_point := nav_agent.get_next_path_position()
		if is_navigation_finished():
			_apply_navigation_velocity(Vector3.ZERO)
			active = false
			return
		var target_velocity := target_movement_speed * npc.npc_movement.global_position.direction_to(next_path_point)
		nav_agent.velocity = target_velocity
		
		if not nav_agent.avoidance_enabled:
			_apply_navigation_velocity(target_velocity)
	
	func _apply_navigation_velocity(vel: Vector3):
		if vel.length() > 0.0:
			var effective_direction := (npc.npc_movement.effective_velocity * Vector3(1.0, 0.0, 1.0)).normalized()
			if effective_direction.is_normalized():
				var new_basis := Basis(Quaternion(Vector3.FORWARD, effective_direction))
				npc.npc_movement.graphics_node.global_basis = new_basis.scaled(npc.npc_movement.graphics_node.global_basis.get_scale())
		npc.npc_movement.desired_movement_velocity = vel

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	navigation = NPCNavigation.new(self)
	vision = NPCVision.new(self)

func _get(property: StringName) -> Variant:
	if property == &"patrol_target":
		return ""
	return null

func _set_patrol_target(target_name: String):
	patrol_route = get_node("../" + target_name)

func _set(property: StringName, value: Variant) -> bool:
	if property == &"patrol_target":
		_set_patrol_target.call_deferred(value)
		return true
	return false
	
func update_vision():
	vision.advance()
	
func _physics_process(delta: float) -> void:
	if navigation.active:
		navigation.advance(delta)
	npc_movement.advance(get_physics_process_delta_time())
	
