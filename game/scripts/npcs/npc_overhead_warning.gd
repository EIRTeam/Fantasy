extends Node3D

class_name NPCOverheadWarning

enum OverheadWarningType {
	ALERT,
	SUSPICIOUS
}

const WARNING_MATERIALS: Dictionary[OverheadWarningType, BaseMaterial3D] = {
	OverheadWarningType.ALERT: preload("res://materials/ui/alert.tres"),
	OverheadWarningType.SUSPICIOUS: preload("res://materials/ui/suspicious.tres")
}

const VISIBLE_TIME := 3.0

@onready var mesh_instance: MeshInstance3D = %MeshInstance3D
@onready var animation_player: AnimationPlayer = %AnimationPlayer

@onready var disappear_timer: Timer = Timer.new()

func _ready() -> void:
	hide()
	add_child(disappear_timer)
	disappear_timer.one_shot = true
	disappear_timer.wait_time = VISIBLE_TIME
	animation_player.animation_finished.connect(self._on_animation_finished)
	disappear_timer.timeout.connect(animation_player.play_backwards.bind(&"disappear"))

func _on_animation_finished(animation: StringName):
	if animation == &"disappear":
		hide()
	else:
		disappear_timer.start()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.is_echo() and event.keycode == KEY_F5:
			show_warning(OverheadWarningType.ALERT)

func show_warning(warning_type: OverheadWarningType):
	mesh_instance.set_surface_override_material(0, WARNING_MATERIALS[warning_type])
	animation_player.play(&"appear")
	show()
