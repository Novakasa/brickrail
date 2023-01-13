extends WindowDialog

export(NodePath) var name_input

var train_name

func setup(p_train_name):
	train_name = p_train_name
	Devices.connect("data_received", self, "_on_data_received")

func _on_data_received(key, data):
	if not visible:
		return
	if key == "device_name_found":
		var name = data
		get_node(name_input).text = name

func get_train():
	return Devices.trains[train_name]

func show():
	popup_centered()
	var train = get_train()
	get_node(name_input).text = train.name

func _on_CancelButton_pressed():
	hide_and_reset()

func hide_and_reset():
	hide()
	get_node(name_input).text = ""

func _on_ScanButton_pressed():
	Devices.find_device("find_train_address")

func _on_OKButton_pressed():
	var new_train_name = get_node(name_input).text
	var train = get_train()
	train.set_name(new_train_name)
	train_name = new_train_name
	hide_and_reset()
