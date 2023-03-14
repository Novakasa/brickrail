extends Panel

signal invert_toggled(value)
signal motor_selected(switch_motor)

var controllername
var port

func setup(p_motor):
	select(p_motor)
	var _err = Devices.connect("layout_controllers_changed", self, "_on_devices_layout_controllers_changed")

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
