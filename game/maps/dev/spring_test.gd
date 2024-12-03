extends Control

var character_spring := CharacterSpring.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var desired := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	character_spring.advance(desired * 1000.0, delta)
	$Sprite2D.global_position = character_spring.velocity
