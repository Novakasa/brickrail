extends Panel

signal invert_toggled(value)
signal motor_selected(switch_motor)

var controllername
var port

func setup(p_motor, inverted):
	select(p_motor)
	var _err = Devices.connect("layout_controllers_changed", self, "_on_devices_layout_controllers_changed")
	$VBoxContainer/GridContainer/InvertCheckBox.pressed = inverted
	update_storage_controls()

func update_storage_controls():
	var storage_node = $VBoxContainer/Storage
	for child in storage_node.get_children():
		storage_node.remove_child(child)
		child.queue_free()
	if controllername == null:
		return
	var controller: LayoutController = Devices.layout_controllers[controllername]
	if controller.devices[port] == null:
		return
	var switch_motor = controller.devices[port]
	var labels = switch_motor.storage_labels
	var max_limits = switch_motor.max_limits
	var order = [0, 1]
	for i in order:
		var label = Label.new()
		label.text = labels[i]
		storage_node.add_child(label)
		if max_limits[i] == -1:
			var checkbox = CheckBox.new()
			var _err = checkbox.connect("toggled", self, "_on_storage_val_edited", [i, "bool"])
			checkbox.pressed = switch_motor.get_stored_value(i)
			storage_node.add_child(checkbox)
		else:
			var edit = SpinBox.new()
			var _err = edit.connect("value_changed", self, "_on_storage_val_edited", [i, "int"])
			edit.max_value = max_limits[i]
			edit.value = switch_motor.get_stored_value(i)
			storage_node.add_child(edit)

func _on_storage_val_edited(value, index, type):
	var controller: LayoutController = Devices.layout_controllers[controllername]
	var switch_motor = controller.devices[port]
	if type == "int":
		switch_motor.store_value(index, int(value))
	if type == "bool":
		switch_motor.store_value(index, int(value))
	LayoutInfo.set_layout_changed(true)

func select(p_motor):
	if p_motor == null:
		controllername = null
		port = null
	else:
		controllername = p_motor.controllername
		port = p_motor.port
	
	setup_options()


func _on_devices_layout_controllers_changed():
	setup_options()

func setup_options():
	var controller_option: Selector = $VBoxContainer/GridContainer/ControllerOption
	controller_option.set_items(Devices.layout_controllers.keys(), Devices.layout_controllers.keys())

	var port_option: Selector = $VBoxContainer/GridContainer/PortOption
	controller_option.select_meta(controllername)
	if controllername == null:
		port_option.set_items([], [])
		return
	
		
	var controller: LayoutController = Devices.layout_controllers[controllername]
	var num_ports = len(controller.devices)
	var portlabels = ["A", "B", "C", "D", "E", "F"].slice(0, num_ports-1)
	var portindices = range(num_ports)
	port_option.set_items(portlabels, portindices)
	port_option.select_meta(port)

func _on_InvertCheckBox_toggled(button_pressed):
	emit_signal("invert_toggled", button_pressed)

func set_motor():
	if port == null or controllername == null:
		emit_signal("motor_selected", null)
		return
	var controller: LayoutController = Devices.layout_controllers[controllername]
	if controller.devices[port] == null:
		controller.set_device(port, "switch_motor")
	var switch_motor = controller.devices[port]
	assert(switch_motor is SwitchMotor)
	emit_signal("motor_selected", switch_motor)

func _on_PortOption_meta_selected(meta):
	port = meta
	set_motor()

func _on_ControllerOption_meta_selected(meta):
	controllername = meta
	setup_options()
	set_motor()
