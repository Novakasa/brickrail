extends WindowDialog

export(NodePath) var name_input

var controller_name

func _on_CancelButton_pressed():
	hide_and_reset()

func setup(p_controller_name):
	controller_name = p_controller_name
	Devices.connect("data_received", self, "_on_data_received")

func _on_data_received(key, data):
	if not visible:
		return
	if key == "device_name_found":
		var name = data
		get_node(name_input).text = name
	
func get_controller():
	return Devices.layout_controllers[controller_name]

func show():
	var controller = get_controller()
	get_node(name_input).text = controller.name
	popup_centered()

func hide_and_reset():
	hide()
	get_node(name_input).text = ""

func _on_OKButton_pressed():
	var new_controller_name = get_node(name_input).text
	var controller = get_controller()
	controller.set_name(new_controller_name)
	controller_name = new_controller_name
	hide_and_reset()

func _on_ScanButton_pressed():
	Devices.find_device("find_controller_address")
