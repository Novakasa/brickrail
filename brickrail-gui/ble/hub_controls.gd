extends HBoxContainer

export(NodePath) var connect_button
export(NodePath) var run_button
export(NodePath) var scan_button

var hub

func setup(p_hub):
	hub = p_hub
	var _err = Devices.get_ble_controller().connect("hubs_state_changed", self, "_on_hubs_state_changed")
	_on_hubs_state_changed()

func _on_hubs_state_changed():
	var controller = Devices.get_ble_controller()
	var control_enabled = controller.hub_control_enabled and not controller.is_busy()
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	var scanbutton = get_node(scan_button)
	
	scanbutton.disabled = not (control_enabled and not hub.connected)
	
	if hub.connected:
		connectbutton.text = "disconnect"
		runbutton.disabled = not control_enabled
	else:
		connectbutton.text = "connect"
		runbutton.disabled = true
	if hub.running:
		runbutton.text = "stop"
		connectbutton.disabled = true
	else:
		runbutton.text = "run"
		connectbutton.disabled = not control_enabled

func _on_run_button_pressed():
	var runbutton = get_node(run_button)
	if runbutton.text == "run":
		hub.run_program_coroutine()
	if runbutton.text == "stop":
		hub.stop_program_coroutine()

func _on_connect_button_pressed():
	var connectbutton = get_node(connect_button)
	if connectbutton.text == "connect":
		hub.connect_coroutine()
	if connectbutton.text == "disconnect":
		hub.disconnect_coroutine()

func _on_scan_button_pressed():
	var new_name = yield(Devices.get_ble_controller().scan_for_hub_name_coroutine(), "completed")
	hub.set_name(new_name)
