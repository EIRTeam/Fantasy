extends Resource

## Establishes materials used for emitting noise from objects, both for the hearing system
## and for the user
class_name HBNoiseMaterial

## Size of the noise radius emitted when an object of this material
## collides at a sufficient speed
@export_range(0.0, 1000.0, 0.001) var noise_radius := 20.0

## Minimum speed at which an object of this material must be traveling to emit a noise
@export_range(0.0, 1000.0, 0.001) var minimum_noise_speed := 100.0
