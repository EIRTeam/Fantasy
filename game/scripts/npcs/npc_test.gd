extends Node3D

class_name NPCTest

var nav_agent: NavigationAgent3D

@export var movement: HBNPCmovement

var target_position: Vector3
var last_calculated_target_position: Vector3

const REPATH_RADIUS := 1.0
const REPATH_RADIUS_2 := REPATH_RADIUS * REPATH_RADIUS

func _ready() -> void:
	nav_agent = NavigationAgent3D.new()
	nav_agent.debug_enabled = true
	movement.add_child(nav_agent)
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 1.5
	nav_agent.debug_enabled = true
	nav_agent.max_speed = movement.get_max_move_speed()
	nav_agent.velocity_computed.connect(self._run_movement)
	nav_agent.time_horizon_obstacles = 0.25
	nav_agent.path_max_distance = 1.0

func force_repath():
	nav_agent.target_position = target_position
	last_calculated_target_position = target_position

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return
	if target_position.distance_squared_to(last_calculated_target_position) > REPATH_RADIUS_2:
		nav_agent.target_position = target_position
	var next_path_point := nav_agent.get_next_path_position()
	var target_velocity := movement.get_max_move_speed() * movement.global_position.direction_to(next_path_point)
	nav_agent.velocity = target_velocity
	
	if not nav_agent.avoidance_enabled:
		_run_movement(target_velocity)

func _run_movement(vel: Vector3):
	if vel.length() > 0.0:
		var effective_direction := (movement.effective_velocity * Vector3(1.0, 0.0, 1.0)).normalized()
		if effective_direction.is_normalized():
			var new_basis := Basis(Quaternion(Vector3.FORWARD, effective_direction))
			movement.graphics_node.global_basis = new_basis.scaled(movement.graphics_node.global_basis.get_scale())
	movement.desired_movement_velocity = vel
	movement.advance(get_physics_process_delta_time())
