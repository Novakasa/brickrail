extends VBoxContainer

@export var connect_button: NodePath
@export var run_button: NodePath
@export var scan_button: NodePath

var hub

func setup(p_hub):
	hub = p_hub
	var _err = Devices.get_ble_controller().connect("hubs_state_changed", Callable(self, "_on_hubs_state_changed"))
	_on_hubs_state_changed()
	_err = hub.connect("battery_changed", Callable(self, "_on_hub_battery_changed"))
	_err = hub.connect("skip_download_changed", Callable(self, "_on_hub_skip_download_changed"))
	$HBoxContainer/DownloadCheckbox.button_pressed = not hub.skip_download

func _on_hub_skip_download_changed(value):
	$HBoxContainer/DownloadCheckbox.button_pressed = not value

func _on_hub_battery_changed():
	$HBoxContainer2/BatteryLabel.text = ("Battery %.2f" % hub.battery_voltage) + "V"

func _on_hubs_state_changed():
	var controller = Devices.get_ble_controller()
	var control_enabled = controller.hub_control_enabled
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
	var new_name = await Devices.get_ble_controller().scan_for_hub_name_coroutine()
	if new_name == null:
		push_error("scanned name is null!")
		return
	hub.set_name(new_name)


func _on_DownloadCheckbox_toggled(button_pressed):
	hub.skip_download = not button_pressed
