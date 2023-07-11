extends VBoxContainer

var controller_name
var controller
var port_selectors = {}

var LayoutControllerPortSelector = preload("res://devices/layout_controller/layout_controller_device_gui.tscn")

@export var controller_label: NodePath
@export var hub_controls: NodePath

func setup(p_controller_name):
	set_controller_name(p_controller_name)
	get_controller().connect("name_changed", Callable(self, "_on_controller_name_changed"))
	get_controller().connect("removing", Callable(self, "_on_controller_removing"))
	get_node(hub_controls).setup(get_controller().hub)
	# $LayoutControllerSettingsDialog.show()
	for port in controller.devices:
		var port_selector = LayoutControllerPortSelector.instantiate()
		port_selector.connect("device_selected", Callable(self, "_on_port_selector_device_selected"))
		port_selectors[port] = port_selector
		$VBoxContainer/PortSelectorContainer.add_child(port_selector)
		port_selector.setup(port)

func _on_port_selector_device_selected(port, type):
	controller.set_output_device(port, type)

func _on_controller_name_changed(_p_old_name, p_new_name):
	set_controller_name(p_new_name)

func _on_controller_removing(_p_name):
	queue_free()

func set_controller_name(p_controller_name):
	controller_name = p_controller_name
	get_node(controller_label).text = controller_name
	controller = Devices.layout_controllers[controller_name]
	if not controller.is_connected("devices_changed", Callable(self, "_on_controller_devices_changed")):
		controller.connect("devices_changed", Callable(self, "_on_controller_devices_changed"))

func _on_controller_devices_changed(_p_name):
	for port in controller.devices:
		if controller.devices[port] == null:
			port_selectors[port].select_device(null)
		else:
			port_selectors[port].select_device(controller.devices[port].device_type)

func get_controller():
	return Devices.layout_controllers[controller_name]

func _on_RemoveButton_pressed():
	await get_controller().safe_remove_coroutine().completed
