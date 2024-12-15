@tool
extends NPCBase

class_name NPCGuard

var brain: RexbotBrain
@onready var overhead_warning: NPCOverheadWarning = %OverheadWarning

## How long the player has been in sight
var player_in_sight_duration := 0.0

static var instant_alert_closeness_cvar := CVar.create(&"guard_instant_alert_distance", TYPE_FLOAT, 3.0, "If closer than this distance, trigger an instant alert")

func _init() -> void:
	npc_settings = preload("res://scripts/npcs/guard/guard_npc_settings.tres")

func _ready() -> void:
	super._ready()
	heard_something_suspicious.connect(overhead_warning.show_warning.bind(NPCOverheadWarning.OverheadWarningType.SUSPICIOUS))
	saw_something_alarming.connect(overhead_warning.show_warning.bind(NPCOverheadWarning.OverheadWarningType.ALERT))
	if Engine.is_editor_hint():
		return
	
	var firearm_test := WeaponInstanceFirearmBase.new()
	weaponry.current_weapon_instance = firearm_test

	brain = RexbotBrain.new()
	brain.actor = self
	brain.intentions.push_back(RexbotIntention.new(brain, NPCGuardMainAction.new()))
	

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
	super._physics_process(delta)
