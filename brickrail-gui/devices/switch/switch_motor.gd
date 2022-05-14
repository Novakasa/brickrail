class_name SwitchMotor
extends Reference

var hub
var port
var position
var responsiveness
var controllername
var device_type = "switch_motor"

signal position_changed(position)
signal responsiveness_changed(value)
signal device_call(port, funcname, args)
signal removing(controllername, port)

func _init(p_hub, p_port, p_controllername):
	port = p_port
	set_hub(p_hub)
	position = "unknown"
	responsiveness = false
	controllername = p_controllername

func set_hub(p_hub):
	if hub != null:
		hub.disconnect("responsiveness_changed", self, "_on_hub_responsiveness_changed")
		hub.disconnect("data_received", self, "_on_hub_data_received")
	hub = p_hub
	if hub != null:
		hub.connect("responsiveness_changed", self, "_on_hub_responsiveness_changed")
		hub.connect("data_received", self, "_on_hub_data_received")

func _on_hub_data_received(key, data):
	if key != "device_data":
		return
	if data.port != port:
		return
	var devkey = data.key
	var devdata = data.data
	_on_device_data_received(devkey, devdata)

func serialize():
	var struct = {}
	struct["type"] = device_type
	return struct

func serialize_reference():
	var struct = {}
	struct["controller"] = controllername
	struct["port"] = port
	return struct

func _on_device_data_received(key, data):
	prints("switch got data", key)
	if key == "position_changed":
		position = data
		set_responsive()
		emit_signal("position_changed", data)

func _on_hub_responsiveness_changed(value):
	if value:
		position = "unknown"
		setup_on_hub()
		set_responsive()
		emit_signal("position_changed", position)
	else:
		set_unresponsive()

func setup_on_hub():
	hub.rpc("add_switch", [port])

func device_call(funcname, args):
	hub.rpc("device_call", [port, funcname, args])

func set_unresponsive():
	responsiveness = false
	emit_signal("responsiveness_changed", false)

func set_responsive():
	responsiveness = true
	emit_signal("responsiveness_changed", true)

func switch(position):
	set_unresponsive()
	device_call("switch", [position])

func remove():
	set_hub(null)
	emit_signal("removing", controllername, port)
