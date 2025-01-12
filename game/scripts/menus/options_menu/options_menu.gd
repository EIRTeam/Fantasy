extends PanelContainer

@onready var section_tabs: TabBar = get_node("%SectionTabs")
@onready var section_container: VBoxContainer = get_node("%SectionContainer")

class OptionEntry:
	var cvar_name: StringName
	var display_tr_key: StringName
	var description_tr_key: StringName
	var enum_entries_tr_keys: Array[StringName]
	func _init(_cvar_name: StringName, _display_tr_key: StringName, _description_tr_key: StringName) -> void:
		cvar_name = _cvar_name
		display_tr_key = _display_tr_key
		description_tr_key = _description_tr_key
	func with_enum(_enum_entries_tr_keys: Array[StringName]) -> OptionEntry:
		enum_entries_tr_keys = _enum_entries_tr_keys
		return self

var entries: Dictionary[String, Array] = {
	tr("#OptionsUI_Graphics_Section"): [
		OptionEntry.new(
			&"mat_scaling_mode",
			&"#OptionsUI_Graphics_ScalingMode_Name",
			&"#OptionsUI_Graphics_ScalingMode_Description"
		).with_enum([&"#OptionsUI_Graphics_ScalingMode_None", &"#OptionsUI_Graphics_ScalingMode_FSR", &"#OptionsUI_Graphics_ScalingMode_FSR2"])
	]
}

func _ready() -> void:
	populate_section_list()
	section_tabs.tab_selected.connect(display_section)

func populate_section_list():
	section_tabs.clear_tabs()
	for section_name in entries:
		section_tabs.add_tab(section_name)
	section_tabs.current_tab = 0

func _on_enum_item_changed(new_value: int, cvar: CVar):
	cvar.value = new_value

func display_section(section_idx: int):
	for entry: OptionEntry in entries.values()[section_idx]:
		var entry_container := HBoxContainer.new()
		var entry_label := Label.new()
		entry_label.text = entry.display_tr_key
		entry_container.add_child(entry_label)
		var cvar := CVar.convars[entry.cvar_name]
		if cvar.property_hint & PROPERTY_HINT_ENUM:
			var entry_selector := OptionButton.new()
			for item in entry.enum_entries_tr_keys:
				entry_selector.add_item(item)
			entry_selector.select(cvar.value)
			entry_selector.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
			entry_selector.item_selected.connect(_on_enum_item_changed.bind(cvar))
			entry_container.add_child(entry_selector)
		section_container.add_child(entry_container)
