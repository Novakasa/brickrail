class_name SwitchMotor
extends Reference

var hub
var port
var position
var responsiveness
var controllername
var device_type = "switch_motor"
var switching = false
var ref_count = 0

var position_to_enum = {"left": 0, "right": 1}

const DATA_SWITCH_CONFIRM = 0

const SWITCH_COMMAND_SWITCH = 0

const STORAGE_PULSE_DC = 0
const STORAGE_PULSE_DURATION = 1
const STORAGE_PULSE_POLARITY = 2

var storage_labels = [
	"Motor pulse speed [DC]",
	"Motor pulse duration [ms]",
	"Invert direction"]

# -1 for boolean config
var max_limits = [100, 10000, -1]
var storage_gui_order = [2, 1, 0]

signal position_changed(position)
signal responsiveness_changed(value)
signal removing(controllername, port)

func _init(p_hub, p_port, p_controllername):
	port = p_port
	set_hub(p_hub)
	position = "unknown"
	responsiveness = false
	controllername = p_controllername
	
	store_value(STORAGE_PULSE_DC, 100)
	store_value(STORAGE_PULSE_DURATION, 600)
	store_value(STORAGE_PULSE_POLARITY, 0)

func store_value(i, value):
	hub.store_value(8 + port*16 + i, value)

func get_stored_value(i):
	return hub.storage[8 + port*16 + i]

func set_hub(p_hub):
	if hub != null:
		hub.disconnect("responsiveness_changed", self, "_on_hub_responsiveness_changed")
		hub.disconnect("runtime_data_received", self, "_on_hub_runtime_data_received")
		hub.disconnect("name_changed", self, "_on_hub_name_changed")
	hub = p_hub
	if hub != null:
		hub.connect("responsiveness_changed", self, "_on_hub_responsiveness_changed")
		hub.connect("runtime_data_received", self, "_on_hub_runtime_data_received")
		hub.connect("name_changed", self, "_on_hub_name_changed")

func _on_hub_runtime_data_received(data):
	if data[0] == DATA_SWITCH_CONFIRM:
		if data[1] != port:
			return
		position = ["left", "right", "none"][data[2]]
		emit_signal("position_changed", position)
		set_responsive()
		switching = false

func serialize():
	var struct = {}
	struct["type"] = device_type
	return struct

func serialize_reference():
	var struct = {}
	struct["controller"] = controllername
	struct["port"] = port
	var storage = {}
	for i in range(len(max_limits)):
		storage[i] = get_stored_value(i)
	struct["storage"] = storage
	return struct

func _on_hub_responsiveness_changed(value):
	if value:
		position = "unknown"
		setup_on_hub()
		set_responsive()
		emit_signal("position_changed", position)
	else:
		set_unresponsive()

func _on_hub_name_changed(old_name, new_name):
	assert(old_name == controllername)
	controllername = new_name

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
	switching = true
	set_unresponsive()
	hub.rpc("device_execute", [port, SWITCH_COMMAND_SWITCH, position_to_enum[p_position]])

func remove():
	set_hub(null)
	emit_signal("removing", controllername, port)
