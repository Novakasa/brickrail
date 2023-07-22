
class_name AsyncFileDialog
extends FileDialog

signal user_action(action, path)

func _ready():
	var _err
	_err = get_cancel_button().connect("pressed", Callable(self, "_on_action").bind("canceled"))
	_err = get_cancel_button().connect("pressed", Callable(self, "_on_action").bind("closed"))
	_err = connect("file_selected", Callable(self, "_on_file_selected"))
	_err = connect("modal_closed", Callable(self, "_on_modal_closed"))

func _on_modal_closed():
	emit_signal("user_action", "closed", null)

func _on_file_selected(path):
	emit_signal("user_action", "file_selected", path)

func _on_action(action):
	emit_signal("user_action", action, null)

func get_file_action_coroutine():
	popup()
	var result = await self.user_action
	return result
	
