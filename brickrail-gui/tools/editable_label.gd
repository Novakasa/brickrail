
class_name EditableLabel
extends VBoxContainer

var label: Label
var edit: LineEdit

export(String) var text

signal text_changed(text)

func _ready():
	label = Label.new()
	add_child(label)
	edit = LineEdit.new()
	add_child(edit)
	label.rect_size = edit.rect_size
	edit.visible = false
	label.text = text
	edit.text = text
	var _err = connect("gui_input", self, "_on_gui_input")
	_err = edit.connect("text_entered", self, "_on_edit_text_entered")

func set_text(p_text):
	text = p_text
	if label != null:
		label.text = text
	if edit != null:
		edit.text = text

func _on_gui_input(event: InputEvent):
	if edit.visible:
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index != BUTTON_LEFT or not event.pressed:
		return
	label.visible = false
	edit.visible = true

func _on_edit_text_entered(_text=null):
	edit.visible = false
	label.visible = true
	label.text = edit.text
	text = edit.text
	emit_signal("text_changed", edit.text)
