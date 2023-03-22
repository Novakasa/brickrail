class_name BLEController
extends Node

var hubs = {}
var hub_control_enabled = true

signal data_received(key, data)
signal hubs_state_changed()
signal device_name_discovered(p_name)

func _ready():
	var _err = $BLECommunicator.connect("message_received", self, "_on_message_received")

func add_hub(hub):
	send_command(null, "add_hub", [hub.name, hub.program], null)
	hubs[hub.name] = hub
	hub.connect("ble_command", self, "_on_hub_command")
	hub.connect("name_changed", self, "_on_hub_name_changed")
	hub.connect("removing", self, "_on_hub_removing")
	hub.connect("state_changed", self, "_on_hub_state_changed")

func _on_hub_name_changed(hubname, new_hubname):
	rename_hub(hubname, new_hubname)

func _on_hub_removing(hubname):
	send_command(null, "remove_hub", [hubname], null)
	hubs.erase(hubname)

func _on_hub_state_changed():
	if not are_hubs_ready() and LayoutInfo.control_devices:
		LayoutInfo.set_control_devices(false)
	emit_signal("hubs_state_changed")

func are_hubs_ready():
	for hub in hubs.values():
		if not hub.running:
			return false
	return true

func is_busy():
	for hub in hubs.values():
		if hub.busy:
			return true
	return false

func rename_hub(p_name, p_new_name):
	var hub = hubs[p_name]
	hubs.erase(p_name)
	hubs[p_new_name] = hub
	send_command(null, "rename_hub", [p_name, p_new_name], null)

func _on_message_received(message):
	var obj = JSON.parse(message).result
	prints("[BLEController] message parsed obj:", obj)
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
	var command = BLECommand.new(hub, funcname, args, return_key)
	$BLECommunicator.send_message(command.to_json())

func _on_hub_command(hub, command, args, return_key):
	send_command(hub, command, args, return_key)

func clean_exit_coroutine():
	if not $BLECommunicator.connected:
		yield(Devices.get_tree(), "idle_frame")
		return
	yield(disconnect_all_coroutine(), "completed")
	hub_control_enabled = false
	emit_signal("hubs_state_changed")
	yield($BLECommunicator.clean_exit_coroutine(), "completed")

func connect_and_run_all_coroutine():
	yield(Devices.get_tree(), "idle_frame")
	hub_control_enabled = false
	emit_signal("hubs_state_changed")
	for hub in hubs.values():
		if not hub.connected:
			var result = yield(hub.connect_coroutine(), "completed")
			if result == "error":
				push_error("connection error!")
				hub_control_enabled = true
				return
		if not hub.running:
			yield(hub.run_program_coroutine(), "completed")
	hub_control_enabled = true
	emit_signal("hubs_state_changed")

func disconnect_all_coroutine():
	yield(Devices.get_tree(), "idle_frame")
	hub_control_enabled = false
	emit_signal("hubs_state_changed")
	for hub in hubs.values():
		if hub.running:
			yield(hub.stop_program_coroutine(), "completed")
		if hub.connected:
			yield(hub.disconnect_coroutine(), "completed")
	hub_control_enabled = true
	emit_signal("hubs_state_changed")

func scan_for_hub_name_coroutine():
	send_command(null, "find_device", [], "return_key")
	var new_name = yield(self, "device_name_discovered")
	return new_name
