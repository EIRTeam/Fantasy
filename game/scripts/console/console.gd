class_name HBConsole

static var singleton: HBConsole

var registered_cvars: Dictionary[StringName, CVar]

signal print_message(message: String)
signal print_err(error: String)

static var help_command: CVar = CVar.create_command(&"help", "Shows this help message")

var autoexec := ConfigFile.new()

const AUTOEXEC_PATH := "user://autoexec.cfg"

class ConVarSearchResult:
	var convars: Array[CVar]
	var similarities: PackedFloat32Array
	var indices: Array[int]
	
	func get_result_count() -> int:
		return indices.size()
	func get_result_at_position(idx: int) -> CVar:
		assert(idx < indices.size())
		return convars[indices[idx]]

func search_convars(text: String) -> ConVarSearchResult:
	var cvar_search_result := ConVarSearchResult.new()
	for convar_name in CVar.convars:
		var convar := CVar.convars[convar_name]
		var similarity := convar.cvar_name.similarity(text)
		if similarity > 0.1:
			if convar_name.begins_with(text):
				similarity *= 2.0
			cvar_search_result.convars.push_back(convar)
			cvar_search_result.similarities.push_back(similarity)
	cvar_search_result.indices.resize(cvar_search_result.convars.size())
	for index in range(cvar_search_result.convars.size()):
		cvar_search_result.indices[index] = index
	cvar_search_result.indices.sort_custom(func(a: int, b: int):
		return cvar_search_result.similarities[a] >= cvar_search_result.similarities[b]
	)
	return cvar_search_result

func print_help():
	var lines: PackedStringArray
	lines.push_back("Here's your help:\n")
	for cvar_name in CVar.convars:
		var cvar := CVar.convars[cvar_name]
		lines.push_back("{cvar_name}\t:\t{cvar_help}".format({
			"cvar_name": cvar.cvar_name,
			"cvar_help": cvar.help_text
		}))
		if cvar.property_hint & PROPERTY_HINT_ENUM:
			var enum_hints := cvar.property_hint_text.split(",")
			for i in range(enum_hints.size()):
				lines.push_back("\t\t{enum_hint_name} = {enum_hint_value}".format({
					"enum_hint_name": enum_hints[i],
					"enum_hint_value": i
				}))
	print_message.emit("\n".join(lines))

func _print_cvar_value(cvar: CVar):
	var out_text := "] {cvar_name} = \"{cvar_value}\"".format({
		"cvar_name": cvar.cvar_name,
		"cvar_value": cvar.value
	})
	print_to_console(out_text)

func print_to_console(message: String):
	print_message.emit(message)

func print_error_to_console(error: String):
	print_err.emit(error)

func handle_user_input(input: String):
	var split_input := input.split(" ")
	if split_input.size() == 0:
		return
	
	print_to_console("> " + input)
	var cvar := CVar.convars.get(StringName(split_input[0]), null) as CVar
	if not cvar:
		print_error_to_console("CVar \"{cvar_name}\" does not exist!".format({"cvar_name": split_input[0]}))
		return
	if cvar.flags & CVar.CVAR_IS_COMMAND_FLAG:
		cvar.notify_command_executed()
		return
	elif split_input.size() == 2 and not split_input[1].is_empty():
		if cvar.cvar_type == TYPE_BOOL:
			# Bools are a special case
			cvar.value = split_input[1] != "0" 
		else:
			var new_value: Variant = type_convert(split_input[1], cvar.cvar_type)
			cvar.value = new_value
		cvar.notify_value_changed()
		if autoexec:
			autoexec.set_value("cvars", cvar.cvar_name, cvar.value)
			autoexec.save(AUTOEXEC_PATH)
	_print_cvar_value(cvar)
	
func _init_console():
	if FileAccess.file_exists(AUTOEXEC_PATH):
		var result := autoexec.load(AUTOEXEC_PATH)
		if result != OK:
			print_error_to_console("autoexec.cfg failed to load with error code %d" % [result])
			autoexec = null
			return
	if autoexec.has_section("cvars"):
		for cvar_name in autoexec.get_section_keys("cvars"):
			var cvar := CVar.convars.get(StringName(cvar_name), null) as CVar
			var value: Variant = autoexec.get_value("cvars", cvar_name)
			if cvar and typeof(value) == cvar.cvar_type:
				cvar.value = value
				cvar.notify_value_changed()
	
func _init() -> void:
	singleton = self
	help_command.command_executed.connect(print_help)
	print_message.connect(print)
	print_err.connect(func(v: String):
		print_rich("[color=red]%s[/color]" % v))

static func get_singleton() -> HBConsole:
	return singleton
