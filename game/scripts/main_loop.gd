extends SceneTree

class_name HBGameMainLoop

var console: HBConsole
var console_ui: ConsoleUI
var debug_overlay: DebugOverlay

# HACK: So CVars are statically initialized... don't even need to call this!
func __cvar_static_init_HACK():
	var _1: HBDebugDraw
	var _2: HBPlayer
	var _3: HearingDebug
	var _4: NPCBase
	var _5: RexbotBrain

static var host_timescale_cvar := CVar.create(&"host_timescale", TYPE_FLOAT, 1.0, "Changes the time scale of the engine")
static var quit_ccommand := CVar.create_command(&"quit", "Quits the game")

func _initialize() -> void:
	console = HBConsole.new()
	debug_overlay = DebugOverlay.new()
	root.add_child(debug_overlay)
	console_ui = preload("res://scenes/console/console_ui.tscn").instantiate()
	root.add_child(console_ui)
	
	host_timescale_cvar.value_changed.connect(func():
		Engine.time_scale = host_timescale_cvar.get_float()
	)
	
	quit_ccommand.command_executed.connect(quit)
	
	console._init_console()

func _physics_process(_delta: float) -> bool:
	if not paused:
		debug_overlay.advance()
	return false
