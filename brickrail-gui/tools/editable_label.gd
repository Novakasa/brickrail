
class_name EditableLabel
extends VBoxContainer

var label: Label
var edit: LineEdit

@export var text: String
@export var display_text: String

var display_different: bool = false

signal text_changed(text)

func _ready():
	label = Label.new()
	add_child(label)
	edit = LineEdit.new()
	add_child(edit)
	label.size = edit.size
	edit.visible = false
	label.text = display_text
	edit.text = text
	var _err = connect("gui_input", Callable(self, "_on_gui_input"))
	_err = edit.connect("text_submitted", Callable(self, "_on_edit_text_entered"))

func set_text(p_text):
	text = p_text
	if not display_different:
		display_text = text
	if label != null and not display_different:
		label.text = text
	if edit != null:
		edit.text = text

func set_display_text(p_text):
	display_different = false
	display_text = p_text
	if label != null:
		label.text = p_text

func _on_gui_input(event: InputEvent):
	if edit.visible:
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	label.visible = false
	edit.visible = true

func _on_edit_text_entered(_text=null):
	edit.visible = false
	label.visible = true
	if not display_different:
		label.text = edit.text
	text = edit.text
	emit_signal("text_changed", edit.text)
