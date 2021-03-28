extends WindowDialog

export(NodePath) var name_input
export(NodePath) var controller_input
export(NodePath) var port_input

var switch_name
var project

func setup(p_project, p_switch_name):
	project = p_project
	switch_name = p_switch_name
	project.connect("data_received", self, "_on_data_received")

func _on_data_received(key, data):
	pass

func get_switch():
	return project.switches[switch_name]

func show():
	var switch = get_switch()
	var controller_input_node = get_node(controller_input)
	controller_input_node.clear()
	controller_input_node.add_item("no controller set")
	for controller in project.layout_controllers.values():
		controller_input_node.add_item(controller.name)
		if controller.name == switch.controller:
			controller_input_node.select(-1)
	if switch.controller == null:
		controller_input_node.select(0)
	
	var port_input_node = get_node(port_input)
	port_input_node.clear()
	port_input_node.add_item("no port set")
	for i in range(4):
		port_input_node.add_item(str(i))
	if switch.port == null:
		port_input_node.select(0)
	else:
		port_input_node.select(switch.port+1)
	
	get_node(name_input).text = switch.name
	popup_centered()

func _on_CancelButton_pressed():
	hide_and_reset()

func hide_and_reset():
	hide()

func _on_ScanButton_pressed():
	project.find_device("find_train_address")

func _on_OKButton_pressed():
	var new_switch_name = get_node(name_input).text
	
	var controller_input_node = get_node(controller_input)
	var new_controller
	if controller_input_node.selected == 0:
		new_controller = null
	else:
		new_controller = controller_input_node.get_item_text(controller_input_node.selected)
	
	var port_input_node = get_node(port_input)
	var new_port
	if port_input_node.selected == 0:
		new_port = null
	else:
		new_port = port_input_node.selected-1
	
	var switch = get_switch()
	switch.set_name(new_switch_name)
	switch_name = new_switch_name
	switch.set_port(new_port)
	switch.set_controller(new_controller)
	hide_and_reset()
