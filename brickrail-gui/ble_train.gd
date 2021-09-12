class_name BLETrain

extends Reference

var name
var hub
var current_speed = 0
var target_speed = 0
var acceleration = 40
var deceleration = 90
var braking = false
var state = "stopped"
var slow_marker = "blue_marker"
var stop_marker = "red_marker"
var mode = "block"

signal state_changed(state)
signal mode_changed(mode)
signal slow_marker_changed(marker)
signal stop_marker_changed(marker)
signal name_changed(old_name, new_name)
signal color_measured(data)

func _init(p_name, p_address):
	name = p_name
	hub = BLEHub.new(p_name, "train", p_address)
	hub.connect("data_received", self, "_on_data_received")
	hub.connect("program_started", self, "_on_hub_program_started")
	Devices.connect("color_added", self, "_on_devices_color_added")

func _on_hub_program_started():
	for color in Devices.colors.values():
		set_color(color)

func _on_devices_color_added(colorname):
	if hub.running:
		var color = Devices.colors[colorname]
		set_color(color)

func set_color(color):
	var hsvlist = color.get_pybricks_colors()
	color.connect("colors_changed", self, "_on_color_colors_changed")
	color.connect("removing", self, "_on_color_removing")
	hub.rpc("set_color", [color.colorname, hsvlist, color.type])

func _on_color_removing(colorname):
	remove_color(colorname)

func remove_color(colorname):
	hub.rpc("remove_color", [colorname])
	Devices.colors[colorname].disconnect("colors_changed", self, "_on_color_colors_changed")
	Devices.colors[colorname].disconnect("removing", self, "_on_color_removing")

func _on_color_colors_changed(colorname):
	remove_color(colorname)
	set_color(Devices.colors[colorname])

func _on_data_received(key, data):
	prints("train received:", key, data)
	if key == "state_changed":
		set_state(data)
	if key == "mode_changed":
		mode = data
		emit_signal("mode_changed", data)
	if key == "slow_marker_changed":
		slow_marker = data
		emit_signal("slow_marker_changed", data)
	if key == "stop_marker_changed":
		stop_marker = data
		emit_signal("stop_marker_changed", data)
	if key == "hsv":
		var color = Color(data[0]/360, data[1]/100, data[2]/100)
		emit_signal("color_measured", data)

func set_state(p_state):
	state = p_state
	emit_signal("state_changed", state)

func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	hub.set_name(p_new_name)
	emit_signal("name_changed", old_name, p_new_name)

func set_target(value):
	var cmd = "train.set_target(" + str(value) + ")"
	hub.hub_command(cmd)

func set_speed(value):
	var cmd = "train.set_speed(" + str(value) + ")"
	hub.hub_command(cmd)

func brake():
	hub.hub_command("train.brake()")

func start():
	hub.rpc("start", [])

func stop():
	hub.rpc("stop", [])

func wait():
	hub.rpc("wait", [])

func slow():
	hub.rpc("slow", [])

func flip_heading():
	hub.rpc("flip_heading", [])

func set_slow_marker(marker):
	slow_marker = marker
	hub.rpc("set_slow_marker", [marker])

func set_stop_marker(marker):
	stop_marker = marker
	hub.rpc("set_stop_marker", [marker])

func set_mode(p_mode):
	mode = p_mode
	hub.rpc("set_mode", [mode])
