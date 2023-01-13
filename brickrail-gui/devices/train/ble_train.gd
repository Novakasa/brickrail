class_name BLETrain

extends Reference

var name
var hub
var route : LayoutRoute

signal name_changed(old_name, new_name)
signal removing(p_name)
signal sensor_advance()

const DATA_ROUTE_COMPLETE = 1
const DATA_LEG_ADVANCE    = 2
const DATA_SENSOR_ADVANCE = 3

var color_name_to_enum = {"yellow": 0, "blue": 1, "green": 2, "red": 3, "none": 15}
var leg_type_to_enum = {"travel": 0, "flip": 1, "start": 2}
var intention_to_enum = {"stop": 0, "pass": 1}

func _init(p_name):
	name = p_name
	hub = BLEHub.new(p_name, "smart_train")
	hub.connect("runtime_data_received", self, "_on_runtime_data_received")
	hub.connect("program_started", self, "_on_hub_program_started")

func serialize():
	var struct = {}
	struct["name"] = name
	return struct

func _on_hub_program_started():
	pass

func set_route(p_route):
	route = p_route
	route.connect("intention_changed", self, "_on_route_intention_changed")
	
	hub.rpc("new_route", null)
	var leg_index = 0
	for leg in route.legs:
		var data = [leg_index]
		for sensor_index in range(len(leg.sensors_dirtracks)):
			var key = leg.sensor_keys[sensor_index]
			var color = leg.sensor_dirtracks.get_sensor().get_colorname()
			var speed = 0
			var composite = (speed << 6) + (key << 4) + color_name_to_enum[color]
			data.append(composite)
		var composite = leg_type_to_enum[leg.get_type()] + intention_to_enum[leg.intention]
		data.append(composite)
		hub.rpc("set_route_leg", data)
		leg_index += 1

func _on_route_intention_changed(leg_index, intention):
	hub.rpc("set_leg_intention", [leg_index, intention_to_enum[intention]])

func _on_runtime_data_received(data):
	prints("train received:",data)
	if data[0] == DATA_SENSOR_ADVANCE:
		emit_signal("sensor_advance", data)

func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	hub.set_name(p_new_name)
	emit_signal("name_changed", old_name, p_new_name)

func fast():
	hub.rpc("execute_behavior", [64 ^ 1])

func start():
	hub.rpc("execute_behavior", [64 ^ 3])

func stop():
	hub.rpc("execute_behavior", [32])

func slow():
	hub.rpc("execute_behavior", [64 ^ 2])

func flip_heading():
	hub.rpc("execute_behavior", [128])

func remove():
	hub.remove()
	emit_signal("removing", name)
