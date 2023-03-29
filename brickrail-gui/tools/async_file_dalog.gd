
class_name AsyncFileDialog
extends FileDialog

signal user_action(action, path)

func _ready():
	var _err
	_err = get_cancel().connect("pressed", self, "_on_action", ["cancelled"])
	_err = get_close_button().connect("pressed", self, "_on_action", ["closed"])
	_err = connect("file_selected", self, "_on_file_selected")
	_err = connect("modal_closed", self, "_on_modal_closed")

func _on_modal_closed():
	emit_signal("user_action", "closed", null)

func _on_file_selected(path):
	emit_signal("user_action", "file_selected", path)

func _on_action(action):
	emit_signal("user_action", action, null)

func get_file_action_coroutine():
	popup()
	var result = yield(self, "user_action")
	return result
	
