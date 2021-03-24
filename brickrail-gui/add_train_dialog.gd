extends WindowDialog

export(NodePath) var address_input
export(NodePath) var name_input

signal add_train(p_name, p_address)

func _on_CancelButton_pressed():
	hide_and_reset()

func hide_and_reset():
	hide()
	get_node(address_input).text = ""
	get_node(name_input).text = ""

func _on_AddButton_pressed():
	var train_name = get_node(name_input).text
	var address = get_node(address_input).text
	if address == "":
		address = null
	emit_signal("add_train", train_name, address)
	hide_and_reset()


func _on_ScanButton_pressed():
	pass # Replace with function body.
