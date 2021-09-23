class_name BLESwitch
extends Reference

var name
var port
var controller
var position
var responsiveness

signal hub_command(cmd)
signal name_changed(p_old_name, p_name)
signal controller_changed(p_old_controller, p_controller)
signal position_changed(position)
signal responsiveness_changed(value)

func _init(p_name, p_controller, p_port):
	name = p_name
	port = p_port
	controller = p_controller
	position = "unknown"
	responsiveness = false

func serialize():
	var struct = {}
	struct["name"] = name
	struct["controller"] = controller
	struct["port"] = port
	return struct

func _on_data_received(key, data):
	prints("switch got data", key)
	if key == "position_changed":
		position = data
		set_responsive()
		emit_signal("position_changed", data)

func _on_hub_responsiveness_changed(value):
	if value:
		position = "unknown"
		set_responsive()
		emit_signal("position_changed", position)
	else:
		set_unresponsive()

func setup_on_hub():
	var hub = Devices.layout_controllers[controller].hub
	# var cmd = "add_switch('"+name+"', "+str(port)+"))"
	hub.rpc("add_switch", [name, port])

	position = "unknown"
	set_responsive()
	emit_signal("position_changed", position)

func device_call(funcname, args):
	var hub = Devices.layout_controllers[controller].hub
	hub.rpc("device_call", [name, funcname, args])

func set_unresponsive():
	responsiveness = false
	emit_signal("responsiveness_changed", false)

func set_responsive():
	responsiveness = true
	emit_signal("responsiveness_changed", true)

func switch(position):
	set_unresponsive()
	device_call("switch", [position])

func set_name(p_name):
	var old_name = name
	name = p_name
	emit_signal("name_changed", old_name, name)

func set_controller(p_controller):
	var old_controller = controller
	controller = p_controller
	emit_signal("controller_changed", name, old_controller, controller)

func set_port(p_port):
	port = p_port
