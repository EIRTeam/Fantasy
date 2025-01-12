extends HBActorEntityBase

class_name NPCBase

@export var patrol_route: HBPathCorner
@export var npc_settings: HBNPCSettingsBase
@export var audio_player: AudioStreamPlayer3D
@onready var audio_playback: AudioStreamPlaybackPolyphonic
var health := 50.0

var navigation: NPCNavigation
var vision: NPCVision
var hearing: NPCAudition
var npc_aiming: NPCAim
var weaponry: NPCWeaponry
var chasing: NPCChasing

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
var npc_movement: HBNPCmovement:
	get:
		return movement

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
		aim_direction = target_aim_direction.normalized()
		if npc_show_aim_cvar.get_bool():
			var eyepos := npc.get_eye_position()
			DebugOverlay.vert_arrow(eyepos, eyepos + aim_direction * Vector3.FORWARD, 0.25, Color.BLUE)
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
		aim_direction = npc.model.global_basis.get_rotation_quaternion()
		weapon_shared.actor_movement = npc
		#weapon_shared.actor_ghost_body = npc.ghost_body
		weapon_shared.actor_hitbox = npc.virtual_hitbox
		weapon_shared.actor_look = npc.model
		weapon_shared.actor_aim_origin = npc.get_eye_position()
		weapon_shared.actor_aim_normal = npc.npc_aiming.get_aiming_direction()
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
		point_query.position = npc.model.global_position
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
	
	static var npc_vision_near_range_cvar := CVar.create(&"npc_vision_near_range", TYPE_FLOAT, 10.0, "Near range for NPC vision")
	static var npc_vision_medium_range_cvar := CVar.create(&"npc_vision_medium_range", TYPE_FLOAT, 25.0, "Medium range for NPC vision")
	static var npc_vision_far_range_cvar := CVar.create(&"npc_vision_far_range", TYPE_FLOAT, 40.0, "Far range for NPC vision")
	static var npc_suspicion_decay_speed_cvar := CVar.create(&"npc_suspicion_decay_speed", TYPE_FLOAT, 0.1, "Decay speed for NPC vision suspicion meters")
	
	enum SuspicionMeterStage {
		NONE,
		SUSPICIOUS,
		ALERT
	}
	
	var suspicion_meter := 0.0
	var suspicion_meter_stage := SuspicionMeterStage.NONE
	
	static var show_vision_cone_cvar := CVar.create(&"npc_show_vision_cone", TYPE_BOOL, false, "Shows the vision cone of NPCs")
	static var show_vision_rings := CVar.create(&"npc_show_vision_rings", TYPE_BOOL, false, "Shows the vision rings of NPCs")
	static var player_overtracking_time := CVar.create(&"npc_player_overtracking_time", TYPE_FLOAT, 0.75, "How many seconds after vision of the player has been lost we should continue to track him for things like chasing")
	var last_player_sighting_time := 0.0
	
	func _init(_npc: NPCBase):
		npc = _npc
	
	func get_caution_fill_rate_multiplier(distance_to_player: float) -> float:
		# TODO: Implement this properly, see https://github.com/EIRTeam/Fantasy/issues/5
		if distance_to_player < NPCBase.NPCVision.npc_vision_near_range_cvar.get_float():
			return 0.3
		elif distance_to_player < NPCBase.NPCVision.npc_vision_medium_range_cvar.get_float():
			return 0.2
		elif distance_to_player < NPCBase.NPCVision.npc_vision_far_range_cvar.get_float():
			return 0.1
		return 0.0
	
	## Increases the current suspicion meter by [param meter_delta], if [param can_change_stage] is [code]true[/code] then it will automatically
	## switch from SUSPICIOUS to ALERT
	func increase_suspicion_meter(meter_delta: float, can_change_stage := false):
		assert(suspicion_meter_stage != SuspicionMeterStage.NONE, "Suspicion meter stage cannot be NONE if we want to increase it")
		suspicion_meter += meter_delta
		suspicion_meter = min(suspicion_meter, 1.0)
		if can_change_stage:
			if suspicion_meter == 1.0:
				if suspicion_meter_stage == SuspicionMeterStage.SUSPICIOUS:
					suspicion_meter_stage = SuspicionMeterStage.ALERT
					suspicion_meter = 0.0
		GameWorld.get_singleton().notify_alert_meters_updated(npc, suspicion_meter_stage, suspicion_meter)
		
	## Increases the current suspicion meter, if [param can_change_stage] is [code]true[/code] then it will automatically
	func decay_suspicion_meter(delta: float, can_change_stage := false):
		if suspicion_meter_stage != SuspicionMeterStage.NONE:
			suspicion_meter -= npc_suspicion_decay_speed_cvar.get_float() * delta
			suspicion_meter = max(suspicion_meter, 0.0)
			
			if can_change_stage:
				if suspicion_meter == 0.0:
					if suspicion_meter_stage == SuspicionMeterStage.ALERT:
						suspicion_meter_stage = SuspicionMeterStage.SUSPICIOUS
						suspicion_meter = 1.0
					elif suspicion_meter_stage == SuspicionMeterStage.SUSPICIOUS:
						suspicion_meter_stage = SuspicionMeterStage.NONE
		GameWorld.get_singleton().notify_alert_meters_updated(npc, suspicion_meter_stage, suspicion_meter)
	func advance(_delta: float):
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = npc.npc_settings.vision_range
		var shape_params := PhysicsShapeQueryParameters3D.new()
		shape_params.collision_mask = HBPhysicsLayers.LAYER_ENTITY_HITBOXES
		var eye_pos := npc.get_eye_position()
		shape_params.transform.origin = eye_pos
		shape_params.shape = sphere_shape
		shape_params.exclude.push_back(npc.npc_movement.body)
		var dss := npc.get_world_3d().direct_space_state
		var shape_query_result := dss.intersect_shape(shape_params)
		
		visible_entities.clear()
		var guard_forward := npc.npc_aiming.get_aiming_direction()
		if shape_query_result.is_empty():
			return
		
		var ray_query := PhysicsRayQueryParameters3D.create(npc.model.global_position, Vector3(), HBPhysicsLayers.LAYER_WORLDSPAWN | HBPhysicsLayers.LAYER_PROPS)
		for result in shape_query_result:
			var collider := result.collider as Node3D
			var dir_to_entity := eye_pos.direction_to(result.collider.global_position)
			if guard_forward.angle_to(dir_to_entity) <= npc.npc_settings.vision_fov * 0.5:
				var visible_entity: Variant
				var visible_entity_position: Vector3
				visible_entity = collider
				visible_entity_position = collider.global_position
				if collider is HBPlayer:
					visible_entity_position = collider.global_position
					last_player_sighting_time = GameWorld.get_singleton().state.game_time
				# Now, check if we can actually see this entity or if we are blocked by something
				ray_query.to = visible_entity_position
				var raycast_result := dss.intersect_ray(ray_query)
				if raycast_result.is_empty():
					visible_entities.push_back(visible_entity)
		if show_vision_cone_cvar.get_bool():
			DebugOverlay.cone_angle(npc.get_eye_position(), npc.get_eye_position() + guard_forward * npc.npc_settings.vision_range, npc.npc_settings.vision_fov, Color(0.0, 1.0, 0.0, 0.1))
		if show_vision_rings.get_bool():
			DebugOverlay.horz_circle(npc.global_position, npc_vision_near_range_cvar.get_float(), Color(1.0, 0.0, 0.0, 0.0))
			DebugOverlay.horz_circle(npc.global_position, npc_vision_medium_range_cvar.get_float(), Color(1.0, 1.0, 0.0, 0.0))
			DebugOverlay.horz_circle(npc.global_position, npc_vision_far_range_cvar.get_float(), Color(0.0, 1.0, 0.0, 0.0))
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
	var target_distance := 0.0
	
	static var navigation_debug_enable_cvar := CVar.create(&"npc_show_nav", TYPE_BOOL, false, "Show navigation and avoidance")
	
	func abort_navigation():
		active = false
		navigation_status = NavigationStatus.FINISHED
		_apply_navigation_velocity(Vector3.ZERO)
	
	func navigate_to_random_point(_movement_speed: float):
		# We should probably make our own at some point so we can keep queries within a range...
		var np := NavigationServer3D.map_get_random_point(npc.get_world_3d().navigation_map, 0xFF, true)
		begin_navigating_to(np, _movement_speed)
	
	func begin_navigating_to(point: Vector3, _movement_speed: float, _target_distance: float = CLOSENESS_THRESHOLD):
		target_position = point
		target_distance = _target_distance
		active = true
		target_movement_speed = _movement_speed
		local_navigation_dirty = true
		var nav_params := NavigationPathQueryParameters3D.new()
		nav_params.simplify_epsilon = 0.1
		nav_params.simplify_path = true
		nav_params.map = npc.get_world_3d().navigation_map
		nav_params.start_position = npc.global_position
		nav_params.target_position = target_position
		var nav_result := NavigationPathQueryResult3D.new()
		navigation_path.clear()
		NavigationServer3D.query_path(nav_params, nav_result)
		current_path_position_idx = 0
		navigation_status = NavigationStatus.NAVIGATING
		navigation_path = nav_result.path
		calculate_local_navigation()
		print("TARGET SPEED", target_movement_speed)
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
		shape_cast_params.transform = npc.global_transform
		shape_cast_params.shape = cylinder
		var navmesh_target_position := navigation_path[current_path_position_idx]
		var target_collision_trf_origin := navmesh_target_position + Vector3(0.0, (npc.get_movement_height() * 0.5) - NAVMESH_HEIGHT, 0.0)
		shape_cast_params.motion = target_collision_trf_origin - npc.global_position
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
			var right := npc.global_position.direction_to(navmesh_target_position).cross(Vector3.UP).normalized()
			for navtest_side: float in [1.0, -1.0]:
				var dir := navtest_side * right * npc.get_movement_radius() * 2.0
				var test_pos := navmesh_target_position + dir + Vector3(0.0, (npc.get_movement_height() * 0.5) - NAVMESH_HEIGHT, 0.0)
				shape_cast_params.motion = test_pos - npc.global_position
				var second_test_result := dss.cast_motion(shape_cast_params)
				if second_test_result == PackedFloat32Array([1.0, 1.0]):
					if navigation_debug_enable_cvar.get_bool():
						DebugOverlay.cylinder(test_pos, cylinder.height, cylinder.radius, Color.GREEN, true, 4.0)
					next_target = navmesh_target_position + dir
					return
				else:
					if navigation_debug_enable_cvar.get_bool():
						DebugOverlay.cylinder(npc.global_position + shape_cast_params.motion * second_test_result[0], cylinder.height, cylinder.radius, Color.DEEP_PINK, true, 4.0)
		
		# TODO: Attempt step navigation
		next_target = navmesh_target_position
	func advance(_delta: float):
		if is_navigation_finished():
			_apply_navigation_velocity(Vector3.ZERO)
			active = false
			return
		if local_navigation_dirty:
			calculate_local_navigation()
		var npc_pos_2d := Vector2(npc.global_position.x, npc.global_position.z)
		if Vector2(next_target.x, next_target.z).distance_to(npc_pos_2d) < CLOSENESS_THRESHOLD:
			# We navigated to the next target succesfuly, time to repath
			current_path_position_idx += 1
			if current_path_position_idx >= navigation_path.size():
				# Looks like we are done navigating, finish it then
				navigation_status = NavigationStatus.FINISHED
				
			local_navigation_dirty = true
		
		var target_velocity := target_movement_speed * npc.global_position.direction_to(next_target)
		_apply_navigation_velocity(target_velocity)
		
		# TODO: reAdd avoidance
		#if not nav_agent.avoidance_enabled:
			#_apply_navigation_velocity(target_velocity)
		# Redraw debug path
		if navigation_debug_enable_cvar.get_bool():
			DebugOverlay.path(navigation_path, true, Color.RED, true)
			DebugOverlay.cylinder(next_target, 1.0, 1.0, Color.BLACK, true)
	
	func _apply_navigation_velocity(vel: Vector3):
		npc.npc_movement.desired_movement_velocity = vel

class NPCChasing:
	var npc: NPCBase
	
	enum ChasingState {
		CHASING,
		TARGET_LOST,
		IDLING
	}
	
	var chasing_state := ChasingState.IDLING
	var chasing_entity: Node3D
	var chasing_position: Vector3
	var last_known_position: Vector3
	var chasing_speed := 0.0
	var target_distance := 0.0
	
	static var npc_chase_repath_distance_cvar := CVar.create("npc_chase_repath_distance", TYPE_FLOAT, 2.0, "How much the entity being chased must deviate from the current target position for us to trigger a repath")
	static var npc_chase_overtime_cvar := CVar.create("npc_chase_overtime", TYPE_FLOAT, 1.0, "How many seconds should we continue to track the chased entity after losing LOS")
	
	var last_line_of_sight_time := 0.0
	
	func _init(_npc: NPCBase):
		npc = _npc
	
	func begin_chasing_entity(entity: Node3D, speed: float):
		if entity != chasing_entity:
			chasing_entity = entity
		chasing_state = ChasingState.CHASING
		chasing_speed = speed
		target_distance = NPCBase.NPCNavigation.CLOSENESS_THRESHOLD
	
	func abort_chase():
		if chasing_state == ChasingState.CHASING:
			npc.navigation.abort_navigation()
		chasing_state = ChasingState.IDLING
	
	func repath():
		npc.navigation.begin_navigating_to(last_known_position, chasing_speed)
		chasing_position = last_known_position
	
	func advance(_delta: float):
		if chasing_state == ChasingState.IDLING:
			return
		var is_target_visible := npc.vision.visible_entities.has(chasing_entity)
		if npc.global_position.distance_to(last_known_position) < target_distance:
			npc.navigation.abort_navigation()
		else:
			var distance_to_target := last_known_position.distance_to(chasing_position)
			if npc.navigation.is_navigation_finished() and distance_to_target > target_distance:
				repath()
				return
		if is_target_visible:
			last_line_of_sight_time = GameWorld.get_singleton().state.game_time
			chasing_state = ChasingState.CHASING
		
		var time_since_last_sighting := GameWorld.get_singleton().state.game_time - last_line_of_sight_time
		if time_since_last_sighting < npc_chase_overtime_cvar.get_float():
			last_known_position = chasing_entity.global_position
			if last_known_position.distance_to(chasing_position) > npc_chase_repath_distance_cvar.get_float():
				repath()
		else:
			if npc.navigation.is_navigation_finished():
				chasing_state = ChasingState.TARGET_LOST

func _create_movement() -> HBBaseMovement:
	return HBNPCmovement.new()

func _ready() -> void:
	add_child(look_at_timer)
	look_at_timer.one_shot = true
	assert(npc_settings)
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	virtual_hitbox = VirtualHitbox.new(self, $StandingCollisionShape.shape)
	
	npc_talk_debug = Label3D.new()
	npc_talk_debug.no_depth_test = true
	npc_talk_debug.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	npc_talk_debug.pixel_size = 0.001
	npc_talk_debug.fixed_size = true
	npc_talk_debug.position.y = 1.0
	add_child(npc_talk_debug)
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
	npc_aiming = NPCAim.new(self)
	weaponry = NPCWeaponry.new(self)
	chasing = NPCChasing.new(self)
	add_to_group(&"can_receive_damage")
	super.initialize()
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
	
func update_vision(delta: float):
	vision.advance(delta)
	
func get_movement_height() -> float:
	return 1.6

func get_movement_radius() -> float:
	return 0.65
	
func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if navigation.active:
		navigation.advance(delta)
	hearing.advance()
	npc_aiming.advance(delta)
	chasing.advance(delta)
	#DebugOverlay.sphere(npc_movement.global_position, 2.0, Color.YELLOW)
	DebugOverlay.horz_arrow(global_position, global_position + npc_movement.desired_movement_velocity.normalized(), 0.5, Color.YELLOW)
	npc_movement.advance(delta)
	if is_looking_at_a_target():
		var look_dir := model.global_position.direction_to(look_at_position) as Vector3
		look_dir.y = 0.0
		look_dir = look_dir.normalized()
		if look_dir.is_normalized():
			model.global_basis = Quaternion(Vector3.FORWARD, look_dir)
	weaponry.advance(delta)
	virtual_hitbox.update(global_position)
	super.advance(delta)
func get_forward() -> Vector3:
	return model.global_basis * Vector3.FORWARD
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
	var bottom := global_position - Vector3()
	var height := npc_movement.get_stance_height(npc_movement.current_stance_idx)
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

func is_dead() -> bool:
	return health <= 0.0
