class_name CVar

static var convars: Dictionary[StringName, CVar]

var cvar_name: StringName
var help_text: String
var cvar_type: int
var value: Variant

const CVAR_IS_COMMAND_FLAG = 1
var flags := 0

signal command_executed
signal value_changed

static func create_command(_cvar_name: StringName, _help_text: String) -> CVar:
	var cvar := CVar.new()
	cvar.flags = CVAR_IS_COMMAND_FLAG
	cvar.cvar_name = _cvar_name
	cvar.help_text = _help_text
	convars[_cvar_name] = cvar
	return cvar

static func create(_cvar_name: StringName, _type: int, _default_val: Variant, _help_text: String) -> CVar:
	if Engine.get_frames_drawn() > 0:
		print_stack()
		push_warning("CVar initialized after frame 0, did you forget to put a class in HBGameMainLoop::__cvar_static_init_HACK?")
	var cvar := CVar.new()
	cvar.cvar_name = _cvar_name
	cvar.cvar_type = _type
	assert(typeof(_default_val) == _type)
	cvar.help_text = _help_text
	cvar.value = _default_val
	convars[_cvar_name] = cvar
	return cvar

func get_bool() -> bool:
	assert(!(flags & CVAR_IS_COMMAND_FLAG))
	assert(cvar_type == TYPE_BOOL)
	return value as bool

func get_float() -> float:
	assert(!(flags & CVAR_IS_COMMAND_FLAG))
	assert(cvar_type == TYPE_FLOAT)
	return value as float

func notify_value_changed():
	value_changed.emit()

func notify_command_executed():
	command_executed.emit()
