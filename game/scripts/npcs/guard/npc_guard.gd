@tool
extends NPCBase

class_name NPCGuard

var brain: RexbotBrain
@onready var overhead_warning: NPCOverheadWarning = %OverheadWarning

## How long the player has been in sight
var player_in_sight_duration := 0.0

func _init() -> void:
	npc_settings = preload("res://scripts/npcs/guard/guard_npc_settings.tres")

func _ready() -> void:
	super._ready()
	heard_something_suspicious.connect(overhead_warning.show_warning.bind(NPCOverheadWarning.OverheadWarningType.SUSPICIOUS))
	if Engine.is_editor_hint():
		return

	brain = RexbotBrain.new()
	brain.actor = self
	brain.intentions.push_back(RexbotIntention.new(brain, NPCGuardMainAction.new()))
	
	var cone_shape := CylinderMesh.new()
	cone_shape.top_radius = 0.0
	cone_shape.height = npc_settings.vision_range
	cone_shape.bottom_radius = (Vector3.FORWARD * npc_settings.vision_range).rotated(Vector3.RIGHT, npc_settings.vision_fov*0.5).y
	
	var mi := MeshInstance3D.new()
	mi.mesh = cone_shape
	mi.basis = Quaternion(Vector3.DOWN, Vector3.FORWARD)
	mi.position.z -= npc_settings.vision_range * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = preload("res://materials/dev/nav_cone_debug.tres")
	npc_movement.graphics_node.add_child(mi)


func _physics_process(delta: float) -> void:
	update_vision()
	var saw_player := false
	for entity in vision.visible_entities:
		if entity is HBPlayer:
			saw_player = true
			break
	if saw_player:
		player_in_sight_duration += delta
	else:
		player_in_sight_duration = 0.0
	brain.tick(delta)
	var debug_text := ""
	var action_stack := brain.intentions[0].action_stack
	for i in range(action_stack.size()-1, -1, -1):
		if not debug_text.is_empty():
			debug_text += " < "
		debug_text += action_stack[i].get_script().get_global_name()
	rexbot_debug.text = debug_text
	super._physics_process(delta)
