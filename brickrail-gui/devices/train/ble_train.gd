class_name BLETrain

extends Reference

var name
var hub
var route : LayoutRoute
var heading = 1
var logging_module

signal name_changed(old_name, new_name)
signal removing(p_name)
signal sensor_advance()

const STORAGE_CHROMA_THRESHOLD   = 0
const STORAGE_MOTOR_ACC          = 1
const STORAGE_MOTOR_DEC          = 2
const STORAGE_MOTOR_FAST_SPEED   = 3
const STORAGE_MOTOR_SLOW_SPEED   = 4
const STORAGE_MOTOR_CRUISE_SPEED = 5
const STORAGE_MOTOR_INVERTED     = 6

var storage_labels = [
	"Sensor chroma threshold",
	"Acceleration [DC/s]",
	"Deceleration [DC/s]",
	"Fast speed [DC]",
	"Slow speed [DC]",
	"Cruise speed [DC]",
	"Invert motor"]

# -1 for boolean config
var max_limits = [10000, 10000, 10000, 100, 100, 100, -1]

const DATA_ROUTE_COMPLETE    = 1
const DATA_LEG_ADVANCE       = 2
const DATA_SENSOR_ADVANCE    = 3
const DATA_UNEXPECTED_MARKER = 4

var color_name_to_enum = {"yellow": 0, "blue": 1, "green": 2, "red": 3, "none": 15}
var leg_type_to_enum = {"travel": 0, "flip": 1, "start": 2}
var intention_to_enum = {"stop": 0, "pass": 1}
var sensor_key_to_enum = {null: 0, "enter": 1, "in": 2, "leave": 3}
var sensor_speed_to_enum = {"fast": 1, "slow": 2, "cruise": 3}

func _init(p_name):
	name = p_name
	hub = BLEHub.new(p_name, "smart_train")
	hub.connect("runtime_data_received", self, "_on_runtime_data_received")
	hub.connect("program_started", self, "_on_hub_program_started")
	hub.connect("name_changed", self, "_on_hub_name_changed")
	var _err = LayoutInfo.connect("sensors_changed", self, "_on_sensors_changed")
	
	hub.store_value(STORAGE_CHROMA_THRESHOLD, 3500)
	hub.store_value(STORAGE_MOTOR_ACC, 40)
	hub.store_value(STORAGE_MOTOR_DEC, 90)
	hub.store_value(STORAGE_MOTOR_SLOW_SPEED, 40)
	hub.store_value(STORAGE_MOTOR_CRUISE_SPEED, 75)
	hub.store_value(STORAGE_MOTOR_FAST_SPEED, 100)
	hub.store_value(STORAGE_MOTOR_INVERTED, 0)
	
	logging_module = "BLETrain-name"

func _on_sensors_changed():
	set_valid_colors()

func set_valid_colors():
	var data = []
	for sensor in LayoutInfo.sensors:
		var color = sensor.get_colorname()
		if color == "none":
			continue
		if color_name_to_enum[color] in data:
			continue
		data.append(color_name_to_enum[color])
	if len(data) == 0:
		data = [0, 1, 2, 3]
		assert(len(data) == len(color_name_to_enum)-1)
	if len(data) == 1:
		# REVISIT: if we send data of len 1 it will be passed as an int, so make it len 2
		# probably should change the argument unpacking in io_hub
		data.append(data[0])
	if hub.running:
		hub.rpc("set_valid_colors", data)

func serialize():
	var struct = {}
	struct["name"] = name
	struct["storage"] = hub.storage
	return struct

func _on_hub_program_started():
	set_valid_colors()

func set_route(p_route):
	if route != null:
		route.disconnect("intention_changed", self, "_on_route_intention_changed")
	route = p_route
	if route != null:
		var _err = route.connect("intention_changed", self, "_on_route_intention_changed")
		download_route(route)

func download_route(p_route):
	hub.rpc("new_route", null)
	if p_route == null:
		return
	for leg_index in range(len(p_route.legs)):
		var leg = p_route.legs[leg_index]
		var data = [leg_index]
		for sensor_index in range(len(leg.sensor_dirtracks)):
			var key = leg.sensor_keys[sensor_index]
			var color = leg.sensor_dirtracks[sensor_index].get_sensor().get_colorname()
			var speed = leg.sensor_dirtracks[sensor_index].sensor_speed
			var composite = (sensor_speed_to_enum[speed] << 6) + (sensor_key_to_enum[key] << 4) + color_name_to_enum[color]
			data.append(composite)
		var composite = leg_type_to_enum[leg.get_type()] + (intention_to_enum[leg.intention]<<4)
		data.append(composite)
		hub.rpc("set_route_leg", data)

func _on_route_intention_changed(leg_index, intention):
	if not LayoutInfo.control_devices==LayoutInfo.CONTROL_ALL:
		return
	hub.rpc("set_leg_intention", [leg_index, intention_to_enum[intention]])

func _on_runtime_data_received(data):
	Logger.info("[%s] received: %s" % [logging_module, data])
	if data[0] == DATA_SENSOR_ADVANCE:
		emit_signal("sensor_advance", data)
	if data[0] == DATA_UNEXPECTED_MARKER:
		var color_names = ["yellow", "blue", "green", "red"]
		var expected = color_names[int(data[1])]
		var measured = color_names[int(data[2])]
		var chroma = (data[3]<<8) + data[4]
		var hue = (data[5]<<8) + data[6]
		var samples = (data[7]<<8) + data[8]
		Logger.info("[%s] unexpected marker. Chroma: %s Hue: %s samples: %s" % [logging_module, chroma, hue, samples])
		var msg = "Train '%s' unexpected marker: Expected %s, but measured %s!" % [name, expected, measured]
		var more_info = msg + "\nChroma: %s Hue: %s samples: %s" % [chroma, hue, samples]
		more_info +="\n\n Was the physical train position consistent with the virtual train position?"
		more_info += "\nIs the sensor positioned correctly?"
		more_info += "\nAre the virtual marker colors and positions consistent with the physical ones?"
		more_info += "\nIs the track 'brackground' free of any high-chroma (saturated and bright) colors?"
		more_info += "\nIs the train able to stop quickly enough? Try increasing the deceleration or decreasing the train speeds."
		GuiApi.show_error(msg, more_info)
		LayoutInfo.emergency_stop()

func _on_hub_name_changed(_p_old_name, p_new_name):
	var old_name = name
	name = p_new_name
	emit_signal("name_changed", old_name, p_new_name)

func advance_route():
	hub.rpc("advance_route", null)

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
	heading *= -1

func safe_remove_coroutine():
	yield(hub.safe_remove_coroutine(), "completed")
	LayoutInfo.set_layout_changed(true)
	emit_signal("removing", name)
