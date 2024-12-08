extends Node3D

class_name HBMuzzleFlash

@onready var timer := Timer.new()

func _ready() -> void:
	hide()
	add_child(timer)
	timer.one_shot = true
	timer.wait_time = 2.0 / 60.0
	timer.timeout.connect(self.hide)

func fire():
	show()
	timer.start()
