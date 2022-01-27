class_name BLETrain

extends Reference

var name
var hub
var state = "stopped"

signal state_changed(state)
signal name_changed(old_name, new_name)
signal color_measured(data)
signal handled_marker(colorname)

func _init(p_name, p_address):
	name = p_name
	hub = BLEHub.new(p_name, "train", p_address)
	hub.connect("data_received", self, "_on_data_received")
	hub.connect("program_started", self, "_on_hub_program_started")
	Devices.connect("color_added", self, "_on_devices_color_added")
	# TODO: color_removed

func serialize():
	var struct = {}
	struct["name"] = name
	struct["address"] = hub.address
	return struct

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
	# hub.rpc("set_color", [color.colorname, hsvlist, color.type])

func set_expect_marker(colorname, behaviour):
	hub.rpc("set_expect_marker", [colorname, behaviour])

func _on_color_removing(colorname):
	remove_color(colorname)

func remove_color(colorname):
	# hub.rpc("remove_color", [colorname])
	if colorname in Devices.colors:
		Devices.colors[colorname].disconnect("colors_changed", self, "_on_color_colors_changed")
		Devices.colors[colorname].disconnect("removing", self, "_on_color_removing")

func _on_color_colors_changed(colorname):
	remove_color(colorname)
	set_color(Devices.colors[colorname])

func _on_data_received(key, data):
	prints("train received:", key, data)
	if key == "state_changed":
		set_state(data)
	if key == "hsv":
		var color = Color.from_hsv(data[0]/360, data[1]/100, data[2]/100)
		emit_signal("color_measured", color)
	if key == "handled_marker":
		emit_signal("handled_marker", data)

func set_state(p_state):
	state = p_state
	emit_signal("state_changed", state)

func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	hub.set_name(p_new_name)
	emit_signal("name_changed", old_name, p_new_name)

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
