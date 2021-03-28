extends WindowDialog

export(NodePath) var address_input
export(NodePath) var name_input

var project
var controller_name

func _on_CancelButton_pressed():
	hide_and_reset()

func setup(p_project, p_controller_name):
	project = p_project
	controller_name = p_controller_name
	project.connect("data_received", self, "_on_data_received")

func _on_data_received(key, data):
	if key == "find_controller_address":
		var address = data
		get_node(address_input).text = address
	
func get_controller():
	return project.layout_controllers[controller_name]

func show():
	var controller = get_controller()
	var address = controller.hub.address
	if address == null:
		address = ""
	get_node(address_input).text = address
	get_node(name_input).text = controller.name
	popup_centered()

func hide_and_reset():
	hide()
	get_node(address_input).text = ""
	get_node(name_input).text = ""

func _on_OKButton_pressed():
	var new_controller_name = get_node(name_input).text
	var new_address = get_node(address_input).text
	if new_address == "":
		new_address = null
	var controller = get_controller()
	controller.set_name(new_controller_name)
	controller_name = new_controller_name
	controller.set_address(new_address)
	hide_and_reset()

func _on_ScanButton_pressed():
	project.find_device("find_controller_address")
