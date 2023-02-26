extends HBoxContainer

export(NodePath) var connect_button
export(NodePath) var run_button

var hub

func setup(p_hub):
	hub = p_hub
	Devices.get_ble_controller().connect("hubs_state_changed", self, "_on_hubs_state_changed")
	_on_hubs_state_changed()

func _on_hubs_state_changed():
	var control_enabled = Devices.get_ble_controller().hub_control_enabled and not hub.busy
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
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
	var connectbutton = get_node(connect_button)
	if runbutton.text == "run":
		hub.run_program()
	if runbutton.text == "stop":
		hub.stop_program()

func _on_connect_button_pressed():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	if connectbutton.text == "connect":
		hub.connect_hub()
	if connectbutton.text == "disconnect":
		hub.disconnect_hub()
