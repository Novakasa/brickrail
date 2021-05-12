class_name BLEHub
extends Reference

var address
var program
var name
var connected = false
var communicator: BLECommunicator

signal data_received(data)
signal ble_command(hub, command, args, return_id)
signal name_changed(p_name, p_new_name)
signal connected
signal disconnected
signal connect_error(data)

func _init(p_name, p_program, p_address):
	name = p_name
	program = p_program
	# communicator = p_communicator
	address = p_address
	
func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	emit_signal("name_changed", old_name, p_new_name)

func set_address(p_address):
	address = p_address
	send_command("set_address", [p_address], null)

func _on_data_received(key, data):
	prints("hub", name, "received data:", data)
	if key == "connected":
		connected=true
		emit_signal("connected")
		return
	if key == "disconnected":
		connected=false
		emit_signal("disconnected")
		return
	if key == "connect_error":
		connected=false
		emit_signal("connect_error", data)
	emit_signal("data_received", key, data)

func send_command(command, args, return_id=null):
	# communicator.send_command(name, command, args, return_id)
	emit_signal("ble_command", name, command, args, return_id)

func connect_hub():
	send_command("connect", [])

func disconnect_hub():
	send_command("disconnect", [])

func run_program():
	send_command("run", [])
	
func hub_command(python_expression):
	send_command("pipe_command", [python_expression])
