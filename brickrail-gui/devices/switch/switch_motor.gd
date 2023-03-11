class_name SwitchMotor
extends Reference

var hub
var port
var position
var responsiveness
var controllername
var device_type = "switch_motor"

var position_to_enum = {"left": 0, "right": 1}

const DATA_SWITCH_CONFIRM = 0

const SWITCH_COMMAND_SWITCH = 0

signal position_changed(position)
signal responsiveness_changed(value)
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
		hub.disconnect("runtime_data_received", self, "_on_hub_runtime_data_received")
	hub = p_hub
	if hub != null:
		hub.connect("responsiveness_changed", self, "_on_hub_responsiveness_changed")
		hub.connect("runtime_data_received", self, "_on_hub_runtime_data_received")

func _on_hub_runtime_data_received(data):
	if data[0] == DATA_SWITCH_CONFIRM:
		if data[1] != port:
			return
		position = ["left", "right", "none"][data[2]]
		emit_signal("position_changed", position)
		set_responsive()

func serialize():
	var struct = {}
	struct["type"] = device_type
	return struct

func serialize_reference():
	var struct = {}
	struct["controller"] = controllername
	struct["port"] = port
	return struct

func _on_hub_responsiveness_changed(value):
	if value:
		position = "unknown"
		setup_on_hub()
		set_responsive()
		emit_signal("position_changed", position)
	else:
		set_unresponsive()

func setup_on_hub():
	# hub.rpc("add_switch", [port])
	pass

func set_unresponsive():
	responsiveness = false
	emit_signal("responsiveness_changed", false)

func set_responsive():
	responsiveness = true
	emit_signal("responsiveness_changed", true)

func switch(p_position):
	set_unresponsive()
	hub.rpc("device_execute", [port, SWITCH_COMMAND_SWITCH, position_to_enum[p_position]])

func remove():
	set_hub(null)
	emit_signal("removing", controllername, port)
