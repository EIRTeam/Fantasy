extends Node3D

class_name HBPlayer

@onready var player_movement: HBPlayerMovement = get_node("%PlayerMovement")
@onready var player_camera: HBPlayerCameraArm = get_node("%PlayerCameraArm")
@onready var player_graphics: Node3D = get_node("%PlayerGraphics")
@onready var player_ghost_body: Node3D = get_node("%GhostBody")

var weapon_instances: Array[WeaponInstance]
var current_weapon_instance: WeaponInstance
var game_time := 0.0

const CROUCH_HEIGHT_OFFSET := 0.4
var camera_tracked_position_height_offset := 0.0

func get_weapon_shared_state() -> WeaponInstance.WeaponShared:
	var shared_state := WeaponInstance.WeaponShared.new()
	shared_state.actor_movement = player_movement
	shared_state.actor_look = player_camera
	shared_state.actor_ghost_body = player_ghost_body
	shared_state.game_time = game_time
	return shared_state
func _ready() -> void:
	player_movement.top_level = true
	player_movement.movement_snapped.connect(_on_movement_snapped)
	weapon_instances.resize(WeaponData.WeaponSlot.size())
	var gravity_gun := WeaponInstanceGravityGun.new()
	gravity_gun.weapon_data = WeaponData.new()
	weapon_instances[WeaponData.WeaponSlot.GRAVITY_GUN] = gravity_gun
	
	gravity_gun.grappled_object.connect(player_camera.set.bind(&"target_camera_offset", player_camera.ADS_CAMERA_OFFSET))
	gravity_gun.grappled_object.connect(player_camera.inertialize_offset)
	
	gravity_gun.released_object.connect(player_camera.set.bind(&"target_camera_offset", player_camera.BASE_CAMERA_OFFSET))
	gravity_gun.released_object.connect(player_camera.inertialize_offset)
	gravity_gun.holstered.connect(player_camera.set.bind(&"target_camera_offset", player_camera.BASE_CAMERA_OFFSET))
	gravity_gun.holstered.connect(player_camera.inertialize_offset)
	
	var throwing_knife := WeaponInstanceThrowingKnife.new()
	throwing_knife.weapon_data = WeaponData.new()
	weapon_instances[WeaponData.WeaponSlot.THROWING_KNIFE] = throwing_knife
	throwing_knife.charge_started.connect(func():
		player_camera.target_camera_fov = HBPlayerCameraArm.BASE_FOV
		player_camera.inertialize_fov()
	)
	throwing_knife.charge_canceled.connect(func():
		player_camera.target_camera_fov = HBPlayerCameraArm.BASE_FOV
		player_camera.inertialize_fov()
	)
	throwing_knife.knife_thrown.connect(func():
		player_camera.target_camera_fov = HBPlayerCameraArm.BASE_FOV
		player_camera.inertialize_fov()
	)
	throwing_knife.charge_progressed.connect(func(progress: float):
		player_camera.target_camera_fov = lerp(HBPlayerCameraArm.BASE_FOV, HBPlayerCameraArm.KNIFE_CHARGED_FOV, progress)
	)
	
	var weapon_shared_state := get_weapon_shared_state()
	
	for weapon in weapon_instances:
		if weapon:
			weapon.init(weapon_shared_state)
	
	select_weapon(WeaponData.WeaponSlot.GRAVITY_GUN)

func select_weapon(weapon_slot: WeaponData.WeaponSlot):
	if weapon_instances[weapon_slot]:
		if current_weapon_instance:
			current_weapon_instance.notify_holster()
		current_weapon_instance = weapon_instances[weapon_slot]
		current_weapon_instance.draw()
	
func get_camera_tracked_position() -> Vector3:
	return player_movement.global_position - Vector3(0.0, camera_tracked_position_height_offset, 0.0)
	
func _on_movement_snapped():
	player_camera.base_tracked_position = get_camera_tracked_position()
	player_camera.inertialize_position()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("crouch_toggle"):
		var new_height_offset := camera_tracked_position_height_offset
		if player_movement.stance == HBPlayerMovement.Stance.CROUCHING:
			if player_movement.try_change_stance(HBPlayerMovement.Stance.STANDING):
				new_height_offset = 0.0
		else:
			if player_movement.try_change_stance(HBPlayerMovement.Stance.CROUCHING):
				new_height_offset = CROUCH_HEIGHT_OFFSET
		if new_height_offset != camera_tracked_position_height_offset:
			camera_tracked_position_height_offset = new_height_offset
			player_camera.base_tracked_position = get_camera_tracked_position()
			player_camera.inertialize_position()
	player_movement.advance(delta)
	player_camera.base_tracked_position = get_camera_tracked_position()
	game_time += delta
	
	if player_movement.get_input().length() > 0.0:
		var effective_direction := (player_movement.effective_velocity * Vector3(1.0, 0.0, 1.0)).normalized()
		if effective_direction.is_normalized():
			var new_basis := Basis(Quaternion(Vector3.FORWARD, effective_direction))
			player_graphics.global_basis = new_basis.scaled(player_graphics.global_basis.get_scale())
			
	if current_weapon_instance:
		var shared_state := get_weapon_shared_state()
		
		var fire_actions: Array[StringName] = [
			&"primary_fire",
			&"secondary_fire"
		]
		
		var fire_functions: Array[Callable] = [
			current_weapon_instance.primary,
			current_weapon_instance.secondary
		]
		
		for i in range(fire_actions.size()):
			var action := fire_actions[i]
			var function := fire_functions[i]
		
			if Input.is_action_pressed(action) or Input.is_action_just_released(action):
				var press_state := WeaponInstance.WeaponPressState.HELD
				if Input.is_action_just_pressed(action):
					press_state = WeaponInstance.WeaponPressState.JUST_PRESSED
				elif Input.is_action_just_released(action):
					press_state = WeaponInstance.WeaponPressState.JUST_RELEASED
				function.call(shared_state, press_state)
		current_weapon_instance._physics_process(shared_state, delta)
	global_position = player_movement.global_position
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_window().set_input_as_handled()
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		if event.keycode == KEY_1:
			select_weapon(WeaponData.WeaponSlot.THROWING_KNIFE)
		elif event.keycode == KEY_2:
			select_weapon(WeaponData.WeaponSlot.GRAVITY_GUN)
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_window().set_input_as_handled()
