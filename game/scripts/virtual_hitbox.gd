# Utility class to give hitboxes to parents of nodes that aren't collision objects, for example, a parent NPC
# this will be replaced eventually by proper animation based hitboxes

class_name VirtualHitbox

var owner: Node3D
var body: RID
func _init(_owner: Node3D, shape: Shape3D) -> void:
	owner = _owner
	body = PhysicsServer3D.body_create()
	PhysicsServer3D.body_attach_object_instance_id(body, owner.get_instance_id())
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_set_collision_layer(body, HBPhysicsLayers.LAYER_ENTITY_HITBOXES)
	PhysicsServer3D.body_set_collision_mask(body, 0)
	PhysicsServer3D.body_add_shape(body, shape.get_rid())
	PhysicsServer3D.body_set_space(body, owner.get_world_3d().space)

func update_transform(position: Vector3):
	var body_trf := Transform3D.IDENTITY
	body_trf.origin = position
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, body_trf)
	
func update(position: Vector3):
	update_transform(position)
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PhysicsServer3D.free_rid(body)
