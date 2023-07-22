class_name AsyncWindow
extends PopupPanel

signal action_button_pressed(action)

var line_edit = null

func _ready():
	pass # Replace with function body.

func set_label(text):
	$VBoxContainer/Label.text = text

func _on_action_button_pressed(action):
	emit_signal("action_button_pressed", action)

func add_text_edit():
	line_edit = LineEdit.new()
	$VBoxContainer.get_children()[0].add_sibling(line_edit)

func add_action_button(action, label):
	var button = Button.new()
	button.text = label
	button.connect("pressed", Callable(self, "_on_action_button_pressed").bind(action))
	$VBoxContainer/actions.add_child(button)

func get_user_action_coroutine():
	popup_centered()
	var action = await self.action_button_pressed
	hide()
	return action
