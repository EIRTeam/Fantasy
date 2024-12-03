@tool
extends NPCBase

class_name NPCGuard

var brain: RexbotBrain
var debug_geo := HBDebugDraw.new()

func _ready() -> void:
	super._ready()
	add_child(debug_geo)
	if Engine.is_editor_hint():
		return

	brain = RexbotBrain.new()
	brain.actor = self
	brain.intentions.push_back(RexbotIntention.new(brain, NPCGuardMainAction.new()))
	
	var cone_shape := CylinderMesh.new()
	cone_shape.top_radius = 0.0
	cone_shape.height = vision_range
	cone_shape.bottom_radius = (Vector3.FORWARD * vision_range).rotated(Vector3.RIGHT, deg_to_rad(vision_fov*0.5)).y
	
	var mi := MeshInstance3D.new()
	mi.mesh = cone_shape
	mi.basis = Quaternion(Vector3.DOWN, Vector3.FORWARD)
	mi.position.z -= vision_range * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = preload("res://materials/dev/nav_cone_debug.tres")
	npc_movement.graphics_node.add_child(mi)


func _physics_process(delta: float) -> void:
	update_vision()
	brain.tick(delta)
	super._physics_process(delta)
