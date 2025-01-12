extends HBActorEntityBase

class_name HBPlayer

var player_movement: HBPlayerMovement:
	get:
		return movement
@onready var player_camera: HBPlayerCameraArm = get_node("%PlayerCameraArm")
@onready var player_graphics: Node3D = get_node("%PlayerGraphics")
@onready var player_ghost_body: Node3D = get_node("%GhostBody")
@onready var weapon_muzzle: Node3D = get_node("%Muzzle")
@onready var muzzle_flash: HBMuzzleFlash = get_node("%MuzzleFlash")
@onready var player_avatar: HBBipedModel = get_node("%PlayerAvatar")
@onready var audio_playback: AudioStreamPlaybackPolyphonic

signal camouflage_index_changed(camo_index: float)

const BASE_CAMERA_OFFSET := Vector3(0.5, -0.2, 1.5)
const ADS_CAMERA_OFFSET := Vector3(0.5, -0.2, 0.75)

var weapon_instances: Array[WeaponInstance]
var current_weapon_instance: WeaponInstance
var game_time := 0.0

var health := 100.0

const CROUCH_HEIGHT_OFFSET := 0.0
const BASE_HEIGHT_OFFSET := 0.6
const ADS_HEIGHT_OFFSET := 0.15
var aim_height_offset := 0.0
var locomotion_camera_height_offset := BASE_HEIGHT_OFFSET

const STEP_FREQUENCY := 1.0
const STEP_NOISE_MAX_RADIUS := 2.0
var noise_emitter_loud: HBNoiseEmitter
var camera_side := 1.0
var prev_camo_index := 0.0

var graphics_rotation_inertializer: RotationInertializer
var weapon_shared_state := WeaponInstance.WeaponShared.new()

var player_animation: BipedAnimationBase:
	get:
		return animation
	

var virtual_hitbox: VirtualHitbox

var weapon_spread := 0.0
signal weapon_equipped(weapon: WeaponInstance)
signal weapon_unequipped(weapon: WeaponInstance)
signal weapon_spread_changed(new_spread: float)
signal health_changed(prev_health: float, new_health: float)

static var current: HBPlayer:
	get:
		if is_instance_valid(current):
			return current
		return null

func update_weapon_shared_state():
	weapon_shared_state.actor_movement = self
	weapon_shared_state.actor_look = player_camera
	weapon_shared_state.actor_ghost_body = player_ghost_body
	weapon_shared_state.game_time = game_time
	var vp_size_2 := get_window().get_final_transform().affine_inverse() * (get_window().size * 0.5)
	weapon_shared_state.actor_aim_normal = player_camera.camera.project_ray_normal(vp_size_2)
	aiming_direction = player_camera.camera.project_ray_normal(vp_size_2)
	weapon_shared_state.actor_aim_origin = player_camera.camera.project_ray_origin(vp_size_2)
	weapon_shared_state.weapon_muzzle_position = weapon_muzzle.global_position
	weapon_shared_state.spread = weapon_spread
	weapon_shared_state.audio_playback = audio_playback
	weapon_shared_state.actor_hitbox = virtual_hitbox
func _update_camera_height_offset():
	player_camera.base_tracked_position = get_camera_tracked_position()
	
func _on_throwing_knife_ended():
	player_camera.target_camera_fov = HBPlayerCameraArm.BASE_FOV
	player_camera.inertialize_fov()
	
func _on_throwing_knife_started():
	player_camera.target_camera_fov = HBPlayerCameraArm.BASE_FOV
	player_camera.inertialize_fov()
	
func _on_round_fired():
	var weapon := current_weapon_instance as WeaponInstanceFirearmBase
	weapon_spread = min(weapon_spread + weapon.firearm_weapon_data.spread_gain_per_shot, weapon.firearm_weapon_data.max_spread)
	weapon_spread_changed.emit(weapon_spread)

func _receive_damage(damage: float):
	var prev_health := health
	health -= damage
	health = max(health, 0.0)
	health_changed.emit(prev_health, health)

func _create_movement() -> HBBaseMovement:
	return HBPlayerMovement.new()

func _ready() -> void:
	# Initialize movement
	super.initialize()
	add_to_group(&"can_receive_damage")
	virtual_hitbox = VirtualHitbox.new(self, $PlayerHitbox.shape)
	(get_node("%AudioStreamPlayer3D") as AudioStreamPlayer3D).play()
	audio_playback = (get_node("%AudioStreamPlayer3D") as AudioStreamPlayer3D).get_stream_playback()
	current = self
	noise_emitter_loud = HBNoiseEmitter.new(STEP_NOISE_MAX_RADIUS)
	add_child(noise_emitter_loud)
	noise_emitter_loud.position = Vector3.ZERO
	player_camera.base_camera_offset = BASE_CAMERA_OFFSET
	_update_camera_height_offset()
	player_movement.movement_snapped.connect(_on_movement_snapped)
	weapon_instances.resize(WeaponData.WeaponSlot.size())
	var gravity_gun := WeaponInstanceGravityGun.new()
	gravity_gun.weapon_data = WeaponData.new()
	weapon_instances[WeaponData.WeaponSlot.GRAVITY_GUN] = gravity_gun
	
	gravity_gun.grappled_object.connect(player_camera.set.bind(&"base_camera_offset", ADS_CAMERA_OFFSET))
	gravity_gun.grappled_object.connect(player_camera.inertialize_offset)
	
	gravity_gun.released_object.connect(player_camera.set.bind(&"base_camera_offset", BASE_CAMERA_OFFSET))
	gravity_gun.released_object.connect(player_camera.inertialize_offset)
	gravity_gun.holstered.connect(player_camera.set.bind(&"base_camera_offset", BASE_CAMERA_OFFSET))
	gravity_gun.holstered.connect(player_camera.inertialize_offset)
	
	var throwing_knife := WeaponInstanceThrowingKnife.new()
	throwing_knife.weapon_data = WeaponData.new()
	weapon_instances[WeaponData.WeaponSlot.THROWING_KNIFE] = throwing_knife
	throwing_knife.charge_started.connect(self._on_throwing_knife_started)
	throwing_knife.charge_canceled.connect(self._on_throwing_knife_ended)
	throwing_knife.knife_thrown.connect(self._on_throwing_knife_ended)
	throwing_knife.charge_progressed.connect(func(progress: float):
		player_camera.target_camera_fov = lerp(HBPlayerCameraArm.BASE_FOV, HBPlayerCameraArm.KNIFE_CHARGED_FOV, progress)
		player_camera.camera_sensitivity = lerp(1.0, 0.1, progress)
	)
	
	var rifle := WeaponInstanceFirearmBase.new()
	weapon_instances[WeaponData.WeaponSlot.TEST_RIFLE] = rifle
	
	for weapon in weapon_instances:
		if weapon is WeaponInstanceFirearmBase:
			weapon.round_fired.connect(muzzle_flash.fire)
			weapon.round_fired.connect(self._on_round_fired)
	
	update_weapon_shared_state()
	
	for weapon in weapon_instances:
		if weapon:
			weapon.init(weapon_shared_state)
	
	PhysicsServer3D.body_add_collision_exception(player_ghost_body.get_rid(), player_movement.body)
	
	select_weapon(WeaponData.WeaponSlot.GRAVITY_GUN)

func select_weapon(weapon_slot: WeaponData.WeaponSlot):
	if weapon_instances[weapon_slot]:
		if current_weapon_instance:
			current_weapon_instance.notify_holster()
			weapon_unequipped.emit(current_weapon_instance)
		current_weapon_instance = weapon_instances[weapon_slot]
		current_weapon_instance.draw()
		weapon_equipped.emit(current_weapon_instance)
		if current_weapon_instance is WeaponInstanceFirearmBase:
			weapon_spread = current_weapon_instance.firearm_weapon_data.base_spread
			weapon_spread_changed.emit(weapon_spread)
	
func get_camera_tracked_position() -> Vector3:
	return global_position + Vector3(0.0, locomotion_camera_height_offset + aim_height_offset, 0.0)
	
func _on_movement_snapped():
	var should_inertialize: bool = abs(player_camera.base_tracked_position.y - get_camera_tracked_position().y) > HBBaseMovement.MAX_STEP_HEIGHT * 0.25
	_update_camera_height_offset()
	DebugOverlay.sphere(global_position, 0.5, Color.BLACK, false, 0.1)
	if should_inertialize:
		player_camera.inertialize_position()



func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"aim"):
		aiming = true
		player_camera.base_camera_offset = ADS_CAMERA_OFFSET
		aim_height_offset = ADS_HEIGHT_OFFSET
		_update_camera_height_offset()
		player_camera.inertialize_offset()
		player_camera.inertialize_position()
		_update_animation_states()
	elif Input.is_action_just_released(&"aim"):
		aiming = false
		player_camera.base_camera_offset = BASE_CAMERA_OFFSET
		aim_height_offset = 0.0
		_update_camera_height_offset()
		player_camera.inertialize_offset()
		player_camera.inertialize_position()
		_update_animation_states()
	if Input.is_action_just_pressed("crouch_toggle"):
		var new_height_offset := locomotion_camera_height_offset
		if player_movement.current_stance_idx == HBPlayerMovement.Stance.CROUCHING:
			if player_movement.try_change_stance(HBPlayerMovement.Stance.STANDING):
				new_height_offset = BASE_HEIGHT_OFFSET
				_update_animation_states()
		else:
			if player_movement.try_change_stance(HBPlayerMovement.Stance.CROUCHING):
				new_height_offset = CROUCH_HEIGHT_OFFSET
				_update_animation_states()
		if new_height_offset != locomotion_camera_height_offset:
			locomotion_camera_height_offset = new_height_offset
			_update_camera_height_offset()
			player_camera.inertialize_position()
	
	super.advance(delta)
	
	if player_movement.effective_velocity.length() > (STEP_NOISE_MAX_RADIUS - 0.1):
		noise_emitter_loud.disabled = false
	else:
		noise_emitter_loud.disabled = true
	
	_update_camera_height_offset()
	game_time += delta
	
	if player_movement.get_input().length() > 0.0:
		var effective_direction := (player_movement.effective_velocity * Vector3(1.0, 0.0, 1.0)).normalized()
		if effective_direction.is_normalized():
			var new_basis := Basis(Quaternion(Vector3.FORWARD, effective_direction))
			player_graphics.global_basis = new_basis.scaled(player_graphics.global_basis.get_scale())
			
	if current_weapon_instance:
		if current_weapon_instance is WeaponInstanceFirearmBase:
			var prev_spread := weapon_spread
			weapon_spread = move_toward(weapon_spread, current_weapon_instance.firearm_weapon_data.base_spread, delta * current_weapon_instance.firearm_weapon_data.spread_decay)
			if prev_spread != weapon_spread:
				weapon_spread_changed.emit(weapon_spread)
		update_weapon_shared_state()
		if aiming or current_weapon_instance is WeaponInstanceGravityGun:
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
					function.call(weapon_shared_state, press_state)
		current_weapon_instance._physics_process(weapon_shared_state, delta)
		
	var new_camo_index := calculate_camouflage_index()
	if new_camo_index != prev_camo_index:
		prev_camo_index = new_camo_index
		camouflage_index_changed.emit(new_camo_index)
		
	virtual_hitbox.update(global_position)
		
	global_position = global_position
	
	DebugOverlay.sphere(global_position, 0.5, Color.BLUE, false, 0.1)
func _process(_delta: float) -> void:
	# Put this here so we don't get interpolation artifacts
	update_weapon_shared_state()
	
func calculate_camouflage_index() -> float:
	var camo_index := 0.0
	var desired_vel := (player_movement.get_input() * player_movement.get_max_move_speed()).length()
	if desired_vel < player_movement.get_max_move_speed() * 0.1:
		camo_index += 0.25
	elif desired_vel < player_movement.get_max_move_speed() - 0.1:
		camo_index += 0.15
	if player_movement.current_stance_idx == HBPlayerMovement.Stance.CROUCHING:
		camo_index += 0.25
	return camo_index
	
func _unhandled_input(event: InputEvent) -> void:
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
		elif event.keycode == KEY_3:
			select_weapon(WeaponData.WeaponSlot.TEST_RIFLE)
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_window().set_input_as_handled()
