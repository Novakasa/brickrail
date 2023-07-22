class_name BLEController
extends Node

var hubs = {}
var hub_control_enabled = false

signal data_received(key, data)
signal hubs_state_changed()
signal device_name_discovered(p_name)

func _ready():
	var _err = $BLECommunicator.connect("message_received", self, "_on_message_received")
	_err = $BLECommunicator.connect("status_changed", self, "_on_hub_state_changed")
	_err = $BLECommunicator.connect("connected", self, "_on_BLEServer_connnected")
	yield(get_tree(), "idle_frame")
	emit_signal("hubs_state_changed") # make gui disable connect buttons etc
	_on_hub_state_changed(null)
	
	yield(setup_process_and_sync_hubs(), "completed")
	
func _on_BLEServer_connnected():
	var logfile = ProjectSettings.globalize_path("user://logs/ble-server.log")
	send_command(null, "start_logfile", [logfile], null)
	for hubname in hubs:
		var hub = hubs[hubname]
		send_command(null, "add_hub", [hubname, hub.program], null)
	return "Ok"

func setup_process_and_sync_hubs():
	var result = yield($BLECommunicator.start_and_connect_to_process(), "completed")
	if result == "Err":
		return "Err"

func add_hub(hub):
	if $BLECommunicator.connected:
		send_command(null, "add_hub", [hub.name, hub.program], null)
	hubs[hub.name] = hub
	hub.connect("ble_command", self, "_on_hub_command")
	hub.connect("name_changed", self, "_on_hub_name_changed")
	hub.connect("removing", self, "_on_hub_removing")
	hub.connect("state_changed", self, "_on_hub_state_changed", [hub])

func _on_hub_name_changed(hubname, new_hubname):
	rename_hub(hubname, new_hubname)

func _on_hub_removing(hubname):
	if $BLECommunicator.connected:
		send_command(null, "remove_hub", [hubname], null)
	hubs.erase(hubname)

func _on_hub_state_changed(_hub=null):
	if $BLECommunicator.connected:
		if not are_hubs_ready() and LayoutInfo.control_devices==LayoutInfo.CONTROL_ALL:
			LayoutInfo.emergency_stop()
		var status = get_hub_status()
		if len(status)>0:
			var hubname = status.keys()[0]
			GuiApi.status_process("["+hubname+"] "+status[hubname]+"...")
		else:
			GuiApi.status_ready("[BLE Server] connected")
		
		hub_control_enabled = (len(status) == 0)
	else:
		if LayoutInfo.control_devices>0:
			LayoutInfo.set_control_devices(LayoutInfo.CONTROL_OFF)
			LayoutInfo.stop_all_trains()
		if $BLECommunicator.busy:
			GuiApi.status_process("[BLE Server] "+$BLECommunicator.status+"...")
		else:
			GuiApi.status_ready("[BLE Server] disconnected")
		hub_control_enabled = false
	emit_signal("hubs_state_changed")

func are_hubs_ready():
	if not $BLECommunicator.connected:
		return false
	for hub in hubs.values():
		if not hub.running:
			return false
	return true

func get_hub_status():
	var status = {}
	for hub in hubs.values():
		if hub.busy:
			status[hub.name] = hub.status
	return status

func rename_hub(p_name, p_new_name):
	var hub = hubs[p_name]
	hubs.erase(p_name)
	hubs[p_new_name] = hub
	if $BLECommunicator.connected:
		send_command(null, "rename_hub", [p_name, p_new_name], null)

func _on_message_received(message):
	var obj = JSON.parse(message).result
	var key = obj.key
	var hubname = obj.hub
	if hubname != null:
		hubs[hubname]._on_data_received(key, obj.data)
		return
	if key == "device_name_found":
		emit_signal("device_name_discovered", obj.data)
		return
	emit_signal("data_received", key, obj.data)

func send_command(hub, funcname, args, return_key):
	assert($BLECommunicator.connected)
	var command = BLECommand.new(hub, funcname, args, return_key)
	$BLECommunicator.send_message(command.to_json())

func _on_hub_command(hub, command, args, return_key):
	assert($BLECommunicator.connected)
	send_command(hub, command, args, return_key)

func clean_exit_coroutine():
	if not $BLECommunicator.connected:
		yield(Devices.get_tree(), "idle_frame")
		return
	yield(disconnect_all_coroutine(), "completed")
	yield($BLECommunicator.clean_exit_coroutine(), "completed")

func connect_and_run_all_coroutine():
	yield(Devices.get_tree(), "idle_frame")
	for hub in hubs.values():
		if not hub.connected:
			var result = yield(hub.connect_coroutine(), "completed")
			if result == "error":
				return "error"
		if not hub.running:
			var result = yield(hub.run_program_coroutine(), "completed")
			if result == "error":
				return "error"
	return "success"

func disconnect_all_coroutine():
	yield(Devices.get_tree(), "idle_frame")
	for hub in hubs.values():
		if hub.running:
			yield(hub.stop_program_coroutine(), "completed")
		if hub.connected:
			yield(hub.disconnect_coroutine(), "completed")

func scan_for_hub_name_coroutine():
	send_command(null, "find_device", [], "return_key")
	var new_name = yield(self, "device_name_discovered")
	return new_name
