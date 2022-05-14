class_name BLETrain

extends Reference

var name
var hub
var state = "stopped"

signal state_changed(state)
signal name_changed(old_name, new_name)
signal handled_marker(colorname)
signal unexpected_marker(colorname)
signal removing(p_name)

func _init(p_name, p_address):
	name = p_name
	hub = BLEHub.new(p_name, "train", p_address)
	hub.connect("data_received", self, "_on_data_received")
	hub.connect("program_started", self, "_on_hub_program_started")

func serialize():
	var struct = {}
	struct["name"] = name
	struct["address"] = hub.address
	return struct

func _on_hub_program_started():
	pass

func set_expect_marker(colorname, behaviour):
	hub.rpc("set_expect_marker", [colorname, behaviour])

func _on_data_received(key, data):
	prints("train received:", key, data)
	if key == "state_changed":
		set_state(data)
	if key == "hsv":
		var color = Color.from_hsv(data[0]/360, data[1]/100, data[2]/100)
		emit_signal("color_measured", color)
	if key == "handled_marker":
		emit_signal("handled_marker", data)
	if key == "detected_unexpected_marker":
		emit_signal("unexpected_marker", data)

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

func remove():
	hub.remove()
	emit_signal("removing", name)
