## Base class all physics objects inherit from
## Takes care of things like audio, damage calculations etc
extends RigidBody3D

class_name HBPhysicsObjectBase

@export var noise_material: HBNoiseMaterial = preload("res://data/noise_materials/noise_material_default.tres")

enum PhysicsObjectFlags {
	CAN_EMIT_NOISE = 1,
	CAN_BE_PICKED_UP = 2,
}

@export_flags("Can emit noise", "Can be picked up") var flags: int = PhysicsObjectFlags.CAN_EMIT_NOISE | PhysicsObjectFlags.CAN_BE_PICKED_UP

var previous_velocity := Vector3.ZERO
@onready var sound_emitter := AudioStreamPlayer3D.new()
var sound_playback: AudioStreamPlaybackPolyphonic

const SOUND_EMISSION_DEBOUNCE_TIME = 0.1
var last_sound_emission_time := 0.0

var debug_draw := HBDebugDraw.new()
var scraping_stream_idx := -1

const NOISE_EMISSION_DEBOUNCE_TIME = 0.25
var last_noise_emission_time := 0.0

func _ready() -> void:
	add_child(sound_emitter)
	sound_emitter.position = Vector3.ZERO
	sound_emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	sound_emitter.stream = AudioStreamPolyphonic.new()
	sound_emitter.play()
	sound_playback = sound_emitter.get_stream_playback()
	collision_layer = HBPhysicsLayers.LAYER_PROPS
	collision_mask = HBPhysicsLayers.LAYER_PROPS | HBPhysicsLayers.LAYER_WORLDSPAWN | HBPhysicsLayers.LAYER_GHOST_BODIES
	contact_monitor = true
	max_contacts_reported = 1
	add_child(debug_draw)

func _play_random_physics_sound(kinetic_energy: float, sound_arr: Array[AudioStream], volume_energy_min: float, volume_energy_max: float):
	if sound_arr.size() > 0:
		var curr_time := Time.get_ticks_msec() / 1000.0
		if curr_time < last_sound_emission_time + SOUND_EMISSION_DEBOUNCE_TIME:
			return
		var sound := sound_arr.pick_random() as AudioStream
		
		var volume_linear := inverse_lerp(volume_energy_min, volume_energy_max, kinetic_energy)
		volume_linear = clamp(volume_linear, 0.0, 1.0)
		var min_db := -30.0
		var max_db := 0.0
		var volume := lerp(min_db, max_db, volume_linear) as float
		sound_playback.play_stream(sound, 0.0, volume, randf_range(0.95, 1.05))
		last_sound_emission_time = curr_time

func can_emit_noise() -> bool:
	return flags & PhysicsObjectFlags.CAN_EMIT_NOISE

func process_scraping(is_scraping: bool, scraping_velocity: float):
	if not is_scraping and scraping_stream_idx != AudioStreamPlaybackPolyphonic.INVALID_ID:
		sound_playback.stop_stream(scraping_stream_idx)
		scraping_stream_idx = AudioStreamPlaybackPolyphonic.INVALID_ID
		print("SCRAPE END")
		return
	if is_scraping and scraping_stream_idx == AudioStreamPlaybackPolyphonic.INVALID_ID:
		scraping_stream_idx = sound_playback.play_stream(noise_material.scrape_smooth_loop)
		print("SCRAPE START")
	if scraping_stream_idx != AudioStreamPlaybackPolyphonic.INVALID_ID:
		var min_db := -30.0
		var max_db := 0.0
		const MAX_SCRAPING_VELOCITY := 10.0
		var scraping_volume_linear := clamp(inverse_lerp(0.0, MAX_SCRAPING_VELOCITY, scraping_velocity), 0.0, 1.0) as float
		var scraping_volume_db := lerp(min_db, max_db, scraping_volume_linear) as float
		
		sound_playback.set_stream_volume(scraping_stream_idx, scraping_volume_db)
		print("VOLUME", scraping_volume_linear)
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var emitted_noise := false
	debug_draw.clear()
	var is_scraping := false
	var scraping_speed := 0.0
	if state.get_contact_count() > 0:
		for i in range(state.get_contact_count()):
			var our_delta_velocity := linear_velocity.length() - previous_velocity.length()
			
			var total_wiped_energy := our_delta_velocity * our_delta_velocity * mass
			var contact_normal := state.get_contact_local_normal(i)
			var contact_velocity := state.get_contact_local_velocity_at_position(i)
			# Check for scraping
			if name == "RigidBody3D":
				var projected_velocity := Plane(contact_normal, Vector3.ZERO).project(contact_velocity)
				var projected_velocity_v := projected_velocity.length()
				scraping_speed = max(scraping_speed, projected_velocity_v)
				is_scraping = projected_velocity_v > 0.25
			debug_draw.draw_line(global_position, global_position + (contact_normal))
			debug_draw.draw_line(global_position, global_position + (state.get_contact_local_velocity_at_position(i).normalized()), Color.GREEN)
			if previous_velocity.length() > noise_material.minimum_sound_speed:
				if total_wiped_energy > noise_material.minimum_sound_energy_delta:
					if total_wiped_energy > noise_material.hard_impact_sound_energy_delta_threshold:
						_play_random_physics_sound(total_wiped_energy, noise_material.hard_impact_sounds, noise_material.hard_impact_sound_energy_delta_threshold, noise_material.volume_energy_max_hard)
					else:
						_play_random_physics_sound(total_wiped_energy, noise_material.soft_impact_sounds, noise_material.minimum_sound_energy_delta, noise_material.hard_impact_sound_energy_delta_threshold)
			
			if name == "RigidBody3D" and total_wiped_energy > 0.3:
				print(total_wiped_energy)
			
			if can_emit_noise() and not emitted_noise and Time.get_ticks_msec() / 1000.0 > (last_noise_emission_time + NOISE_EMISSION_DEBOUNCE_TIME) \
					and previous_velocity.length() > noise_material.minimum_noise_speed and total_wiped_energy > noise_material.minimum_noise_energy_delta:
				var noise_emitter := HBNoiseEmitter.new(noise_material.noise_radius, true)
				noise_emitter.top_level = true
				noise_emitter.position = global_position
				add_child(noise_emitter)
				emitted_noise = true
				last_noise_emission_time = Time.get_ticks_msec() / 1000.0
	process_scraping(is_scraping, scraping_speed)

func _physics_process(_delta: float) -> void:
	previous_velocity = linear_velocity
