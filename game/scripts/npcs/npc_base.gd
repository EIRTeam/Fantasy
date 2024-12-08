@tool
extends RexbotNPCBase

class_name NPCBase

@export var patrol_route: HBPathCorner
@export var npc_settings: HBNPCSettingsBase
var health := 50.0

var target: Vector3
var navigation: NPCNavigation
var vision: NPCVision
var hearing: NPCAudition
var aiming: NPCAim

signal heard_something_suspicious

var debug_geo := HBDebugDraw.new()
var rexbot_debug: Label3D

var looking_at_something := 0.0
var look_at_position := Vector3.ZERO
@onready var look_at_timer := Timer.new()

var virtual_hitbox: VirtualHitbox

class NPCAim:
	enum AimMode {
		FOLLOW_MOVEMENT,
		LOOK_AT_TARGET_POSITION,
		LOOK_AT_TARGET_ENTITY
	}
	
	var npc: NPCBase
	var target_position: Vector3
	var aim_mode: AimMode = AimMode.FOLLOW_MOVEMENT
	
	func _init(_npc: NPCBase) -> void:
		npc = _npc
	
	func aim_at_position(p_position: Vector3):
		aim_mode = AimMode.LOOK_AT_TARGET_POSITION
		target_position = p_position
	
	func advance(delta: float):
		match aim_mode:
			AimMode.FOLLOW_MOVEMENT:
				if npc.npc_movement.desired_velocity.length_squared() > 0.0:
					var effective_direction := (npc.npc_movement.desired_velocity.normalized() * Vector3(1.0, 0.0, 1.0)).normalized()
					if effective_direction.is_normalized():
						var new_basis := Basis(Quaternion(Vector3.FORWARD, effective_direction))
						npc.npc_movement.graphics_node.global_basis = new_basis.scaled(npc.npc_movement.graphics_node.global_basis.get_scale())
			AimMode.LOOK_AT_TARGET_POSITION:
				var dir_to_target := npc.npc_movement.global_position.direction_to(target_position)
				var target_direction := (dir_to_target.normalized() * Vector3(1.0, 0.0, 1.0)).normalized()
				if target_direction.is_normalized():
					var new_basis := Basis(Quaternion(Vector3.FORWARD, target_direction))
					npc.npc_movement.graphics_node.global_basis = new_basis.scaled(npc.npc_movement.graphics_node.global_basis.get_scale())
class NPCWeaponry:
	var npc: NPCBase
	var weapon_instance: WeaponInstanceFirearmBase
	var weapon_shared = WeaponInstance.WeaponShared.new()
	
	func _init(_npc: NPCBase):
		npc = _npc
	
	func update_weapon_shared():
		weapon_shared.actor_movement = npc.npc_movement
		weapon_shared.actor_ghost_body = npc.npc_movement.ghost_physics_body
	
	func advance(delta: float):
		pass
	
class NPCAudition:
	var npc: NPCBase
	var heard_points: PackedVector3Array
	signal sound_heard(position: Vector3)
	func _init(_npc: NPCBase) -> void:
		npc = _npc
	
	func advance():
		var point_query := PhysicsPointQueryParameters3D.new()
		point_query.position = npc.npc_movement.global_position
		point_query.collision_mask = HBPhysicsLayers.LAYER_HEARING
		point_query.collide_with_areas = true
		point_query.collide_with_bodies = false
		var point_query_out := npc.get_world_3d().direct_space_state.intersect_point(point_query)
		heard_points.clear()
		for data in point_query_out:
			var noise_emitter := data.collider as HBNoiseEmitter
			if not noise_emitter:
				continue
			var new_pos := noise_emitter.global_position
			heard_points.push_back(new_pos)
			sound_heard.emit(new_pos)

class NPCVision:
	var npc: NPCBase
	var visible_entities: Array[Node3D]
	
	func _init(_npc: NPCBase):
		npc = _npc
	
	func advance():
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = npc.npc_settings.vision_range
		var shape_params := PhysicsShapeQueryParameters3D.new()
		shape_params.collision_mask = HBPhysicsLayers.LAYER_ENTITY_HITBOXES
		shape_params.transform.origin = npc.npc_movement.global_position
		shape_params.shape = sphere_shape
		shape_params.exclude.push_back(npc.npc_movement.get_rid())
		var dss := npc.get_world_3d().direct_space_state
		var shape_query_result := dss.intersect_shape(shape_params)
		
		visible_entities.clear()
		var guard_forward := npc.npc_movement.graphics_node.global_basis * Vector3.FORWARD
		if shape_query_result.is_empty():
			return
		
		var ray_query := PhysicsRayQueryParameters3D.create(npc.npc_movement.global_position, Vector3(), HBPhysicsLayers.LAYER_WORLDSPAWN | HBPhysicsLayers.LAYER_PROPS)
		for result in shape_query_result:
			var collider := result.collider as Node3D
			var dir_to_entity := npc.npc_movement.global_position.direction_to(result.collider.global_position)
			if guard_forward.angle_to(dir_to_entity) <= npc.npc_settings.vision_fov * 0.5:
				var visible_entity: Variant
				var visible_entity_position: Vector3
				visible_entity = collider
				visible_entity_position = collider.global_position
				if collider is HBPlayer:
					visible_entity_position = collider.player_movement.global_position
				# Now, check if we can actually see this entity or if we are blocked by something
				ray_query.to = visible_entity_position
				var raycast_result := dss.intersect_ray(ray_query)
				if raycast_result.is_empty():
					visible_entities.push_back(visible_entity)
				else:
					print("BLOCKED!", raycast_result)

class NPCNavigation:
	var npc: NPCBase
	enum NavigationStatus {
		FINISHED,
		NAVIGATING
	}
	var target_position: Vector3
	const REPATH_RADIUS := 1.0
	const NAVMESH_HEIGHT = 0.5
	const REPATH_RADIUS_2 := REPATH_RADIUS * REPATH_RADIUS
	var active := false
	var target_movement_speed := 2.0
	var navigation_path: PackedVector3Array
	var current_path_position_idx := -1
	var local_navigation_dirty := false
	var next_target := Vector3()
	const CLOSENESS_THRESHOLD := 0.5
	var navigation_status := NavigationStatus.FINISHED
	
	const NAVPATH_DEBUG_LAYER := &"nav_path"
	const LOCAL_NAV_DEBUG_LAYER := &"local_nav"
	
	func abort_navigation():
		active = false
		_apply_navigation_velocity(Vector3.ZERO)
	
	func begin_navigating_to(point: Vector3, _movement_speed: float):
		target_position = point
		active = true
		var nav_agent := npc.nav_agent
		target_movement_speed = _movement_speed
		local_navigation_dirty = true
		var nav_params := NavigationPathQueryParameters3D.new()
		nav_params.simplify_epsilon = 0.1
		nav_params.simplify_path = true
		nav_params.map = npc.get_world_3d().navigation_map
		nav_params.start_position = npc.npc_movement.global_position
		nav_params.target_position = target_position
		var nav_result := NavigationPathQueryResult3D.new()
		navigation_path.clear()
		NavigationServer3D.query_path(nav_params, nav_result)
		current_path_position_idx = 0
		navigation_status = NavigationStatus.NAVIGATING
		navigation_path = nav_result.path
		
		# Redraw debug path
		npc.debug_geo.clear(NAVPATH_DEBUG_LAYER)
		npc.debug_geo.draw_path(navigation_path, true, Color.RED, NAVPATH_DEBUG_LAYER)
	func _init(_npc: NPCBase) -> void:
		npc = _npc
		npc.debug_geo.create_debug_layer(NAVPATH_DEBUG_LAYER)
		npc.debug_geo.create_debug_layer(LOCAL_NAV_DEBUG_LAYER)
	
	func is_navigation_finished() -> bool:
		return navigation_status == NavigationStatus.FINISHED
	
	func calculate_local_navigation():
		npc.debug_geo.clear(LOCAL_NAV_DEBUG_LAYER)
		# Fire a shapecast towards the destination
		var dss := npc.get_world_3d().direct_space_state
		var cylinder := CylinderShape3D.new()
		cylinder.radius = npc.get_movement_radius()
		cylinder.height = npc.get_movement_height()
		var shape_cast_params := PhysicsShapeQueryParameters3D.new()
		shape_cast_params.collision_mask = HBPhysicsLayers.LAYER_WORLDSPAWN
		shape_cast_params.transform = npc.npc_movement.global_transform
		shape_cast_params.shape = cylinder
		var navmesh_target_position := navigation_path[current_path_position_idx]
		var target_collision_trf_origin := navmesh_target_position + Vector3(0.0, (npc.get_movement_height() * 0.5) - NAVMESH_HEIGHT, 0.0)
		shape_cast_params.motion = target_collision_trf_origin - npc.npc_movement.global_position
		var shape_cast_result := dss.cast_motion(shape_cast_params)
		local_navigation_dirty = false
		if shape_cast_result == PackedFloat32Array([1.0, 1.0]):
			# All good
			next_target = navmesh_target_position
			return
		else:
			npc.debug_geo.draw_shape(cylinder, target_collision_trf_origin, Color.RED, LOCAL_NAV_DEBUG_LAYER)
			# We found a problem, we will now try to move this to the side to make it navigation doable
			var right := npc.npc_movement.global_position.direction_to(navmesh_target_position).cross(Vector3.UP).normalized()
			for navtest_side: float in [1.0, -1.0]:
				var dir := navtest_side * right * npc.get_movement_radius()
				var test_pos := navmesh_target_position + dir + Vector3(0.0, (npc.get_movement_height() * 0.5) - NAVMESH_HEIGHT, 0.0)
				shape_cast_params.motion = test_pos - npc.npc_movement.global_position
				var second_test_result := dss.cast_motion(shape_cast_params)
				if second_test_result == PackedFloat32Array([1.0, 1.0]):
					npc.debug_geo.draw_shape(cylinder, test_pos, Color.GREEN, LOCAL_NAV_DEBUG_LAYER)
					next_target = navmesh_target_position + dir
					return
		# TODO: Attempt step navigation
		next_target = navmesh_target_position
	func advance(delta: float):
		var npc_pos_2d := Vector2(npc.npc_movement.global_position.x, npc.npc_movement.global_position.z)
		if Vector2(next_target.x, next_target.z).distance_to(npc_pos_2d) < CLOSENESS_THRESHOLD:
			# We navigated to the next target succesfuly, time to repath
			current_path_position_idx += 1
			if current_path_position_idx >= navigation_path.size():
				# Looks like we are done navigating, finish it then
				navigation_status = NavigationStatus.FINISHED
				
			local_navigation_dirty = true
		
		if is_navigation_finished():
			_apply_navigation_velocity(Vector3.ZERO)
			active = false
			return
			
		if local_navigation_dirty:
			calculate_local_navigation()
		var target_velocity := target_movement_speed * npc.npc_movement.global_position.direction_to(next_target)
		_apply_navigation_velocity(target_velocity)
		
		# TODO: reAdd avoidance
		#if not nav_agent.avoidance_enabled:
			#_apply_navigation_velocity(target_velocity)
	
	func _apply_navigation_velocity(vel: Vector3):
		npc.npc_movement.desired_movement_velocity = vel

func _ready() -> void:
	add_child(look_at_timer)
	look_at_timer.one_shot = true
	assert(npc_settings)
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	virtual_hitbox = VirtualHitbox.new(self, npc_movement.stance_collision_shapes[HBBaseMovement.Stance.STANDING].shape)
	rexbot_debug = Label3D.new()
	rexbot_debug.no_depth_test = true
	rexbot_debug.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	rexbot_debug.pixel_size = 0.001
	rexbot_debug.fixed_size = true
	npc_movement.add_child(rexbot_debug)
	add_child(debug_geo)
	hearing = NPCAudition.new(self)
	navigation = NPCNavigation.new(self)
	vision = NPCVision.new(self)
	aiming = NPCAim.new(self)
	add_to_group(&"can_receive_damage")

func _get(property: StringName) -> Variant:
	if property == &"patrol_target":
		return ""
	return null

func _set_patrol_target(target_name: String):
	patrol_route = get_node("../" + target_name)

func _receive_damage(damage: float):
	health = max(health - damage, 0.0)

func _set(property: StringName, value: Variant) -> bool:
	if property == &"patrol_target":
		_set_patrol_target.call_deferred(value)
		return true
	return false
	
func update_vision():
	vision.advance()
	
func get_movement_height() -> float:
	return 1.6

func get_movement_radius() -> float:
	return 0.5
	
func _physics_process(delta: float) -> void:
	if navigation.active:
		navigation.advance(delta)
	hearing.advance()
	npc_movement.advance(get_physics_process_delta_time())
	if is_looking_at_a_target():
		var look_dir := npc_movement.graphics_node.global_position.direction_to(look_at_position) as Vector3
		look_dir.y = 0.0
		look_dir = look_dir.normalized()
		if look_dir.is_normalized():
			npc_movement.graphics_node.global_basis = Quaternion(Vector3.FORWARD, look_dir)
	virtual_hitbox.update(npc_movement.global_position)
	aiming.advance(delta)
func get_forward() -> Vector3:
	return npc_movement.graphics_node.global_basis * Vector3.FORWARD
## Makes the NPC look at the given [param target_position], for a given [param duration], if [param duration] is 0 it will never
## stop looking at it
func look_at_target_position(target_position: Vector3, duration := 3.0):
	look_at_position = target_position
	look_at_timer.wait_time = duration
	look_at_timer.start()

func is_looking_at_a_target() -> bool:
	return not look_at_timer.is_stopped()
