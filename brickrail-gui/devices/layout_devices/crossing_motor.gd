class_name CrossingMotor
extends Reference

var hub
var port
var position
var responsiveness
var controllername
var device_type = "crossing_motor"

const CROSSING_COMMAND_SET_POS = 8

const STORAGE_PULSE_DC = 0
const STORAGE_PULSE_DURATION = 1
const STORAGE_PULSE_POLARITY = 2

var position_to_enum = {"up": 1, "down": 0}

var storage_labels = [
	"Motor pulse speed [DC]",
	"Motor pulse duration [ms]",
	"Invert direction"]

# -1 for boolean config
var max_limits = [100, 10000, -1]
var storage_gui_order = [1, 0, 2]

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
	hub = p_hub
	if hub != null:
		hub.connect("responsiveness_changed", self, "_on_hub_responsiveness_changed")
		hub.connect("runtime_data_received", self, "_on_hub_runtime_data_received")

func set_position(p_position):
	if position == p_position:
		return
	hub.rpc("device_execute", [port, CROSSING_COMMAND_SET_POS, [position_to_enum[p_position]]])
	position = p_position

func _on_hub_runtime_data_received(_data):
	pass

func _on_hub_responsiveness_changed(_responsiveness):
	pass

func serialize():
	var struct = {}
	struct["type"] = device_type
	return struct

func remove():
	set_hub(null)
	emit_signal("removing", controllername, port)
