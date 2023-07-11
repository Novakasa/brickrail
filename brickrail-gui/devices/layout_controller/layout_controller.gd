class_name LayoutController
extends RefCounted

var name
var hub
var devices = {}

signal name_changed(p_name, p_new_name)
signal devices_changed(p_name)
signal removing(p_name)

func _init(p_name):
	name = p_name
	
	for port in range(4):
		devices[port] = null
		
	hub = BLEHub.new(p_name, "layout_controller")
	hub.connect("runtime_data_received", Callable(self, "_on_hub_runtime_data_received"))
	hub.connect("program_started", Callable(self, "_on_hub_program_started"))
	hub.connect("responsiveness_changed", Callable(self, "_on_hub_responsiveness_changed"))
	hub.connect("name_changed", Callable(self, "_on_hub_name_changed"))

func _on_hub_program_started():
	pass

func serialize():
	var struct = {}
	struct["name"] = name
	struct["devices"] = {}
	for port in devices:
		if devices[port] == null:
			struct["devices"][port] = null
			continue
		struct["devices"][port] = devices[port].device_type
	return struct

func set_output_device(port, type):
	if devices[port] != null:
		devices[port].remove()
	var device
	if type == "switch_motor":
		device = SwitchMotor.new(hub, port, name)
	elif type == "crossing_motor":
		device = CrossingMotor.new(hub, port, name)
	elif type == null:
		if devices[port] != null:
			devices[port].remove()
		return
	else:
		assert(false)
	devices[port] = device
	device.connect("removing", Callable(self, "_on_device_removing"))
	emit_signal("devices_changed", name)
	return device

func _on_device_removing(_controllername, port):
	devices[port].disconnect("removing", Callable(self, "_on_device_removing"))
	devices[port] = null
	emit_signal("devices_changed", name)

func _on_hub_runtime_data_received(_data):
	pass

func device_call(port, funcname, args):
	hub.rpc("device_call", [port, funcname, args])

func _on_hub_responsiveness_changed(_value):
	pass

func _on_hub_name_changed(_p_old_name, p_new_name):
	var old_name = name
	name = p_new_name
	emit_signal("name_changed", old_name, p_new_name)

func set_address(p_address):
	hub.set_address(p_address)

func safe_remove_coroutine():
	for device in devices.values():
		if device == null:
			continue
		device.remove()
	await hub.safe_remove_coroutine().completed
	LayoutInfo.set_layout_changed(true)
	emit_signal("removing", name)
