extends LineEdit

class_name ConsoleInputLineEdit

@onready var autocomplete_popup_menu: PopupMenu = PopupMenu.new()

func _trigger_autocomplete_popup(text_val: String):
	if text_val.is_empty():
		return
	var cvar_search_result := HBConsole.get_singleton().search_convars(text_val)
	autocomplete_popup_menu.hide()
	if cvar_search_result.get_result_count() == 0:
		return
	autocomplete_popup_menu.clear()
	for i in range(cvar_search_result.get_result_count()):
		autocomplete_popup_menu.add_item("{cvar_name} {cvar_value}".format({
			"cvar_name": cvar_search_result.get_result_at_position(i).cvar_name,
			"cvar_value": cvar_search_result.get_result_at_position(i).value
		}))
		autocomplete_popup_menu.set_item_metadata(autocomplete_popup_menu.item_count-1, cvar_search_result.get_result_at_position(i).cvar_name)
	autocomplete_popup_menu.set_flag(Window.FLAG_NO_FOCUS, true)
	autocomplete_popup_menu.popup(Rect2(global_position + Vector2(0.0, size.y), Vector2.ZERO))
	autocomplete_popup_menu.set_flag(Window.FLAG_NO_FOCUS, false)
	grab_focus()

func _trigger_tab_autocomplete():
	var cvar_search_result := HBConsole.get_singleton().search_convars(text)
	if cvar_search_result.get_result_count() == 0:
		return
	text = cvar_search_result.get_result_at_position(0).cvar_name + " "
	caret_column = text.length()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_TAB:
			_trigger_tab_autocomplete()
			accept_event()
	
func _ready() -> void:
	# TODO: Godot has currently broken focus when making a popup menu appear
	#text_changed.connect(_trigger_autocomplete_popup)
	autocomplete_popup_menu.exclusive = false
	add_child(autocomplete_popup_menu)
