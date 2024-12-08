extends RigidBody3D

class_name HBPhysicsObjectBase

@export var noise_material: HBNoiseMaterial = preload("res://data/noise_materials/noise_material_default.tres")

var can_emit_noise := true

var previous_velocity := Vector3.ZERO

func _ready() -> void:
	collision_layer = HBPhysicsLayers.LAYER_PROPS
	collision_mask = HBPhysicsLayers.LAYER_PROPS | HBPhysicsLayers.LAYER_WORLDSPAWN | HBPhysicsLayers.LAYER_GHOST_BODIES
	contact_monitor = true
	max_contacts_reported = 1

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if can_emit_noise:
		if state.get_contact_count() > 0:
			if previous_velocity.length() > noise_material.minimum_noise_speed:
				var noise_emitter := HBNoiseEmitter.new(noise_material.noise_radius, true)
				noise_emitter.top_level = true
				noise_emitter.position = global_position
				add_child(noise_emitter)

func _physics_process(delta: float) -> void:
	previous_velocity = linear_velocity
