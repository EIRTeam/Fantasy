extends CanvasLayer

class_name ConsoleUI

@onready var console_input: LineEdit = %ConsoleInputLineEdit
@onready var console_text_label: RichTextLabel = %ConsoleText
@onready var toggle_window_button: Button = %ToggleWindowButton
@onready var main_container: Control = %ConsoleContainer

var window: Window

func toggle_window():
	if not window:
		# DIRTY as fuck, but it works! AHAHAHAH!
		window = Window.new()
		window.hide()
		window.force_native = true
		window.title = "Consolen't"
		window.size = get_viewport().size
		get_parent().add_child(window)
		get_parent().remove_child(self)
		window.add_child(self)
		window.show()
		window.close_requested.connect(toggle_window)
	else:
		var wp := window.get_parent()
		window.remove_child(self)
		wp.add_child(self)
		window.queue_free()
		window = null
	_update_console_container_anchors()
func _ready() -> void:
	toggle_window_button.pressed.connect(toggle_window)
	console_input.text_submitted.connect(HBConsole.get_singleton().handle_user_input)
	console_input.text_submitted.connect(func(_text: String):
		console_input.clear()
		console_input.caret_column = 0
		console_input.grab_focus()
	)
	
	HBConsole.get_singleton().print_message.connect(print_to_console)
	HBConsole.get_singleton().print_err.connect(print_error_to_console)
	
	hide()
	
	process_mode = Node.PROCESS_MODE_ALWAYS

func _update_console_container_anchors():
	if window:
		main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		main_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		main_container.set_anchor(SIDE_BOTTOM, 0.4, true)

func print_error_to_console(error: String):
	console_text_label.newline()
	console_text_label.push_color(Color.RED)
	console_text_label.append_text(error)
	console_text_label.pop()

func print_to_console(text: String):
	console_text_label.newline()
	console_text_label.append_text(text)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_console"):
		visible = !visible
		get_tree().paused = visible
		if visible:
			console_input.grab_focus()
