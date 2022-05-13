class_name LayoutController
extends Reference

var name
var hub
var devices = {}

signal name_changed(p_name, p_new_name)
signal device_data_received(p_port, p_key, p_data)
signal devices_changed(p_name)

func _init(p_name, p_address):
	name = p_name
	
	for port in range(4):
		devices[port] = null
		
	hub = BLEHub.new(p_name, "layout_controller", p_address)
	hub.connect("data_received", self, "_on_data_received")
	hub.connect("program_started", self, "_on_hub_program_started")
	hub.connect("responsiveness_changed", self, "_on_hub_responsiveness_changed")

func serialize():
	var struct = {}
	struct["name"] = name
	struct["address"] = hub.address
	return struct

func set_device(port, type):
	if devices[port] != null:
		devices[port].remove()
	var device
	if type == "switch_motor":
		device = SwitchMotor.new(hub, port, name)
	elif type == null:
		if devices[port] != null:
			devices[port].remove()
		return
	else:
		assert(false)
	devices[port] = device
	device.connect("removing", self, "_on_device_removing")
	emit_signal("devices_changed", name)
	return device

func _on_device_removing(_controllername, port):
	devices[port].disconnect("removing", self, "_on_device_removing")
	devices[port] = null
	emit_signal("devices_changed", name)

func _on_data_received(key, data):
	if key == "device_data":
		var devkey = data.key
		var devport = data.port
		var devdata = data.data
		emit_signal("device_data_received", devport, devkey, devdata)

func device_call(port, funcname, args):
	hub.rpc("device_call", [port, funcname, args])

func _on_hub_responsiveness_changed(value):
	emit_signal("hub_responsiveness_changed")

func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	hub.set_name(p_new_name)
	emit_signal("name_changed", old_name, p_new_name)

func set_address(p_address):
	hub.set_address(p_address)
