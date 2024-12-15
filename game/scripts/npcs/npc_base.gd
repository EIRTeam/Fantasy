@tool
extends RexbotNPCBase

class_name NPCBase

@export var patrol_route: HBPathCorner
@export var npc_settings: HBNPCSettingsBase
@export var audio_player: AudioStreamPlayer3D
@onready var audio_playback: AudioStreamPlaybackPolyphonic
var health := 50.0

var target: Vector3
var navigation: NPCNavigation
var vision: NPCVision
var hearing: NPCAudition
var aiming: NPCAim
var weaponry: NPCWeaponry

signal heard_something_suspicious
signal saw_something_alarming

var debug_geo := HBDebugDraw.new()
var npc_talk_debug: Label3D
var npc_talk_debug_timer: Timer

var looking_at_something := 0.0
var look_at_position := Vector3.ZERO
@onready var look_at_timer := Timer.new()
@onready var muzzle := %Muzzle

var virtual_hitbox: VirtualHitbox

class NPCAim:
	enum AimMode {
		FOLLOW_MOVEMENT,
		LOOK_AT_TARGET_POSITION,
		LOOK_AT_TARGET_ENTITY
	}
	
	var npc: NPCBase
	
	var target_position: Vector3
	var target_entity: Node3D
	var aim_mode: AimMode = AimMode.FOLLOW_MOVEMENT
	var game_time := 0.0
	var aim_end_time := -1.0
	var current_target_position: Vector3
	var last_target_update_time := 0.0
	var target_aim_direction: Quaternion
	var aim_direction: Quaternion
	
	static var npc_show_aim_cvar := CVar.create(&"npc_show_aim", TYPE_BOOL, false, "Shows the aiming direction of the NPC")
	
	func _init(_npc: NPCBase) -> void:
		npc = _npc
	
	func aim_at_position(p_position: Vector3, duration := 0.0):
		aim_mode = AimMode.LOOK_AT_TARGET_POSITION
		target_position = p_position
		if duration > 0.0:
			aim_end_time = game_time + duration
		else:
			aim_end_time = -1
		current_target_position = target_position
		
	func get_aiming_direction() -> Vector3:
		return aim_direction * Vector3.FORWARD
	
	func get_target_aim_direction() -> Vector3:
		return target_aim_direction * Vector3.FORWARD
		
	func get_target_update_frequency():
		return 0.5
	
	func advance(delta: float):
		game_time += delta
		match aim_mode:
			AimMode.FOLLOW_MOVEMENT:
				if npc.npc_movement.desired_velocity.length_squared() > 0.0:
					var effective_direction := (npc.npc_movement.desired_velocity.normalized() * Vector3(1.0, 0.0, 1.0)).normalized()
					if effective_direction.is_normalized():
						var new_basis := Quaternion(Vector3.FORWARD, effective_direction)
						target_aim_direction = new_basis
			AimMode.LOOK_AT_TARGET_POSITION:
				if last_target_update_time <= game_time - (1.0/get_target_update_frequency()):
					current_target_position = target_position
				var eye_pos := npc.get_eye_position()
				var dir_to_target := eye_pos.direction_to(current_target_position)
				target_aim_direction = Quaternion(Vector3.FORWARD, dir_to_target)
				if aim_end_time > 0.0 and game_time >= aim_end_time:
					aim_mode = AimMode.FOLLOW_MOVEMENT
		# TODO: Interpolation of aiming directions
		aim_direction = target_aim_direction
		if npc_show_aim_cvar.get_bool():
			var eyepos := npc.get_eye_position()
			DebugOverlay.vert_arrow(eyepos, eyepos + aim_direction * Vector3.FORWARD, 0.25, Color.BLUE)
		# Project forward on the plane defined by the world up to rotate it
		var proj_forward := Plane(Vector3.UP).project(aim_direction * Vector3.FORWARD).normalized()
		if proj_forward.is_normalized():
			npc.npc_movement.graphics_node.global_basis = Basis(Quaternion(Vector3.FORWARD, proj_forward)).scaled(npc.npc_movement.graphics_node.global_basis.get_scale()).orthonormalized()
class NPCWeaponry:
	var npc: NPCBase
	var current_weapon_instance: WeaponInstanceFirearmBase:
		set(val):
			if current_weapon_instance:
				current_weapon_instance.round_fired.disconnect(self._on_round_fired)
			current_weapon_instance = val
			current_weapon_instance.round_fired.connect(self._on_round_fired)

	var weapon_shared = WeaponInstance.WeaponShared.new()
	const AIM_HEIGHT := 1.0
	var aim_direction: Quaternion
	var game_time := 0.0
	
	enum WeaponState {
		IDLE,
		FIRING_BURST
	}
	
	var weapon_state := WeaponState.IDLE
	
	var burst_firings_left := 0
	
	func _init(_npc: NPCBase):
		npc = _npc
	
	func _on_round_fired():
		burst_firings_left -= 1
	
	func is_firing():
		return weapon_state == WeaponState.FIRING_BURST
	
	func fire_burst():
		weapon_state = WeaponState.FIRING_BURST
		# TODO: Make this configurable
		burst_firings_left = 3
	
	func update_weapon_shared():
		aim_direction = npc.npc_movement.graphics_node.global_basis.get_rotation_quaternion()
		weapon_shared.actor_movement = npc.npc_movement
		weapon_shared.actor_ghost_body = npc.npc_movement.ghost_physics_body
		weapon_shared.actor_hitbox = npc.virtual_hitbox
		weapon_shared.actor_look = npc.npc_movement.graphics_node
		weapon_shared.actor_aim_origin = npc.get_eye_position()
		weapon_shared.actor_aim_normal = npc.aiming.get_aiming_direction()
		weapon_shared.weapon_muzzle_position = npc.muzzle.global_position
		weapon_shared.game_time = game_time
		weapon_shared.audio_playback = npc.audio_playback
	
	func advance(delta: float):
		game_time += delta
		update_weapon_shared()
		DebugOverlay.line(weapon_shared.actor_aim_origin, weapon_shared.actor_aim_origin + weapon_shared.actor_aim_normal, Color.HOT_PINK)
		if current_weapon_instance:
			if weapon_state == WeaponState.FIRING_BURST:
				current_weapon_instance.primary(weapon_shared, WeaponInstance.WeaponPressState.HELD)
				if burst_firings_left <= 0:
					current_weapon_instance.primary(weapon_shared, WeaponInstance.WeaponPressState.JUST_RELEASED)
					weapon_state = WeaponState.IDLE
			current_weapon_instance._physics_process(weapon_shared, delta)
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
	
	static var show_vision_cone_cvar := CVar.create(&"npc_show_vision_cone", TYPE_BOOL, false, "Shows the vision cone of NPCs")
	
	func _init(_npc: NPCBase):
		npc = _npc
	
	func advance():
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = npc.npc_settings.vision_range
		var shape_params := PhysicsShapeQueryParameters3D.new()
		shape_params.collision_mask = HBPhysicsLayers.LAYER_ENTITY_HITBOXES
		var eye_pos := npc.get_eye_position()
		shape_params.transform.origin = eye_pos
		shape_params.shape = sphere_shape
		shape_params.exclude.push_back(npc.npc_movement.get_rid())
		var dss := npc.get_world_3d().direct_space_state
		var shape_query_result := dss.intersect_shape(shape_params)
		
		visible_entities.clear()
		var guard_forward := npc.aiming.get_aiming_direction()
		if shape_query_result.is_empty():
			return
		
		var ray_query := PhysicsRayQueryParameters3D.create(npc.npc_movement.global_position, Vector3(), HBPhysicsLayers.LAYER_WORLDSPAWN | HBPhysicsLayers.LAYER_PROPS)
		for result in shape_query_result:
			var collider := result.collider as Node3D
			var dir_to_entity := eye_pos.direction_to(result.collider.global_position)
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
		if show_vision_cone_cvar.get_bool():
			DebugOverlay.cone_angle(npc.get_eye_position(), npc.get_eye_position() + guard_forward * npc.npc_settings.vision_range, npc.npc_settings.vision_fov, Color(0.0, 1.0, 0.0, 0.1))

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
	const CLOSENESS_THRESHOLD := 0.1
	var navigation_status := NavigationStatus.FINISHED
	
	static var navigation_debug_enable_cvar := CVar.create(&"npc_show_nav", TYPE_BOOL, false, "Show navigation and avoidance")
	
	func abort_navigation():
		active = false
		_apply_navigation_velocity(Vector3.ZERO)
	
	func begin_navigating_to(point: Vector3, _movement_speed: float):
		target_position = point
		active = true
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
		if navigation_debug_enable_cvar.get_bool():
			DebugOverlay.path(navigation_path, true, Color.RED, true, 3.0)
	func _init(_npc: NPCBase) -> void:
		npc = _npc
	
	func is_navigation_finished() -> bool:
		return navigation_status == NavigationStatus.FINISHED
	
	func calculate_local_navigation():
		# Fire a shapecast towards the destination
		var dss := npc.get_world_3d().direct_space_state
		var cylinder := CylinderShape3D.new()
		cylinder.radius = npc.get_movement_radius()
		# Reduce height a bit for margin, otherwise we might collide with the floor
		cylinder.height = npc.get_movement_height() - 0.01
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
			if navigation_debug_enable_cvar.get_bool():
				DebugOverlay.cylinder(target_collision_trf_origin, cylinder.height, cylinder.radius, Color.RED, true, 4.0)
			# We found a problem, we will now try to nudge this to the side and see if that fixes it...
			var right := npc.npc_movement.global_position.direction_to(navmesh_target_position).cross(Vector3.UP).normalized()
			for navtest_side: float in [1.0, -1.0]:
				var dir := navtest_side * right * npc.get_movement_radius() * 2.0
				var test_pos := navmesh_target_position + dir + Vector3(0.0, (npc.get_movement_height() * 0.5) - NAVMESH_HEIGHT, 0.0)
				shape_cast_params.motion = test_pos - npc.npc_movement.global_position
				var second_test_result := dss.cast_motion(shape_cast_params)
				if second_test_result == PackedFloat32Array([1.0, 1.0]):
					if navigation_debug_enable_cvar.get_bool():
						DebugOverlay.cylinder(test_pos, cylinder.height, cylinder.radius, Color.GREEN, true, 4.0)
					next_target = navmesh_target_position + dir
					return
				else:
					if navigation_debug_enable_cvar.get_bool():
						DebugOverlay.cylinder(npc.npc_movement.global_position + shape_cast_params.motion * second_test_result[0], cylinder.height, cylinder.radius, Color.DEEP_PINK, true, 4.0)
		# TODO: Attempt step navigation
		next_target = navmesh_target_position
	func advance(_delta: float):
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
	
	npc_talk_debug = Label3D.new()
	npc_talk_debug.no_depth_test = true
	npc_talk_debug.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	npc_talk_debug.pixel_size = 0.001
	npc_talk_debug.fixed_size = true
	npc_talk_debug.position.y = 1.0
	npc_movement.add_child(npc_talk_debug)
	npc_talk_debug_timer = Timer.new()
	add_child(npc_talk_debug_timer)
	npc_talk_debug_timer.wait_time = 3.0
	npc_talk_debug_timer.one_shot = true
	npc_talk_debug_timer.timeout.connect(func(): npc_talk_debug.text = "")
	
	
	add_child(debug_geo)
	
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()
	
	hearing = NPCAudition.new(self)
	navigation = NPCNavigation.new(self)
	vision = NPCVision.new(self)
	aiming = NPCAim.new(self)
	weaponry = NPCWeaponry.new(self)
	add_to_group(&"can_receive_damage")
	npc_movement.top_level = true

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
	return 0.65
	
func _physics_process(delta: float) -> void:
	if navigation.active:
		navigation.advance(delta)
	hearing.advance()
	aiming.advance(delta)
	#DebugOverlay.sphere(npc_movement.global_position, 2.0, Color.YELLOW)
	DebugOverlay.horz_arrow(npc_movement.global_position, npc_movement.global_position + npc_movement.desired_movement_velocity.normalized(), 0.5, Color.YELLOW)
	npc_movement.advance(delta)
	if is_looking_at_a_target():
		var look_dir := npc_movement.graphics_node.global_position.direction_to(look_at_position) as Vector3
		look_dir.y = 0.0
		look_dir = look_dir.normalized()
		if look_dir.is_normalized():
			npc_movement.graphics_node.global_basis = Quaternion(Vector3.FORWARD, look_dir)
	weaponry.advance(delta)
	virtual_hitbox.update(npc_movement.global_position)
	global_position = npc_movement.global_position
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

func _npc_talk(text: String):
	npc_talk_debug.text = text
	npc_talk_debug_timer.start()

func get_eye_height() -> float:
	return 1.2

func get_eye_position() -> Vector3:
	var bottom := npc_movement.global_position - Vector3()
	var height := npc_movement.get_stance_height(npc_movement.stance)
	bottom.y -= height * 0.5
	return bottom + Vector3(0.0, get_eye_height(), 0.0)
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_F5:
			weaponry.fire_burst()

func notify_heard_something_suspicious():
	heard_something_suspicious.emit()
func notify_saw_something_alarming():
	saw_something_alarming.emit()
