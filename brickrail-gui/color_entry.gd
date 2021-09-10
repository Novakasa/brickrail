extends HBoxContainer

signal removing()
signal color_changed()

func get_entry_color():
	return $ColorPickerButton.color

func set_entry_color(p_color):
	$ColorPickerButton.color = p_color
	emit_signal("color_changed")

func _on_MinusButton_pressed():
	emit_signal("removing")
	queue_free()


func _on_ColorPickerButton_color_changed(color):
	emit_signal("color_changed")
