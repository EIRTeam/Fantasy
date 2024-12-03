extends DamageableRigidBody

class_name DestroyableRigidBody

@export var health := 20.0
signal destroyed

func _ready() -> void:
	super._ready()
	damage_received.connect(_on_damage_received)

func _on_damage_received(damage: float):
	health = max(health - damage, 0.0)
	if not is_queued_for_deletion():
		queue_free()
		destroyed.emit()
