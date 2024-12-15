extends Resource

## Establishes materials used for emitting noise from objects, both for the hearing system
## and for the user
class_name HBNoiseMaterial

## Size of the noise radius emitted when an object of this material
## collides at a sufficient speed
@export_range(0.0, 1000.0, 0.001) var noise_radius := 20.0

## Minimum speed at which an object of this material must be traveling to emit a noise
@export_range(0.0, 1000.0, 0.001) var minimum_noise_speed := 100.0

@export_range(0.0, 1000.0, 0.001) var minimum_sound_speed := 0.5

## Kinetic energy required to be lost for a noise to be emitted
@export_range(0.0, 1000.0, 0.001) var minimum_noise_energy_delta := 60.0

@export_range(0.0, 1000.0, 0.001) var minimum_sound_energy_delta := 0.75
@export var soft_impact_sounds: Array[AudioStream]

@export_range(0.0, 1000.0, 0.001) var hard_impact_sound_energy_delta_threshold := 100.0
@export var hard_impact_sounds: Array[AudioStream]

@export var scrape_smooth_loop: AudioStream

## Maximum kinetic energy for volume (1 volume)
@export_range(0.0, 1000.0, 0.001) var volume_energy_max_hard := 150.0
