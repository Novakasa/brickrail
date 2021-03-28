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

signal state_changed(state)
signal name_changed(old_name, new_name)

func _init(p_name, p_address):
	name = p_name
	hub = BLEHub.new(p_name, "train", p_address)
	hub.connect("data_received", self, "_on_data_received")

func _on_data_received(key, data):
	if key == "state_changed":
		set_state(data.state)

func set_state(p_state):
	state = p_state
	emit_signal("state_changed", state)

func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	hub.set_name(p_new_name)
	emit_signal("name_changed", old_name, p_new_name)

func set_address(p_address):
	hub.set_address(p_address)

func set_target(value):
	var cmd = "train.set_target(" + str(value) + ")"
	hub.hub_command(cmd)

func set_speed(value):
	var cmd = "train.set_speed(" + str(value) + ")"
	hub.hub_command(cmd)

func connect_hub():
	hub.connect_hub()

func run_program():
	hub.run_program()

func brake():
	hub.hub_command("train.brake()")

func start():
	hub.hub_command("train.start()")

func stop():
	hub.hub_command("train.stop()")

func wait():
	hub.hub_command("train.wait()")

func slow():
	hub.hub_command("train.slow()")
