class_name BLEHub
extends Reference

var program
var name
var connected = false
var running = false
var communicator: BLECommunicator
var responsiveness = false

signal runtime_data_received(data)
signal ble_command(hub, command, args, return_id)
signal name_changed(p_name, p_new_name)
signal connected
signal disconnected
signal connect_error(data)
signal program_started
signal program_stopped
signal responsiveness_changed(value)
signal removing(name)

func _init(p_name, p_program):
	name = p_name
	program = p_program

func set_responsiveness(val):
	responsiveness = val
	emit_signal("responsiveness_changed", val)
	
func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	emit_signal("name_changed", old_name, p_new_name)

func _on_data_received(key, data):
	prints("hub", name, "received data:", data)
	if key == "connected":
		connected=true
		emit_signal("connected")
		return
	if key == "disconnected":
		connected=false
		emit_signal("disconnected")
		set_responsiveness(false)
		return
	if key == "connect_error":
		connected=false
		emit_signal("connect_error", data)
		return
	if key == "program_started":
		running=true
		emit_signal("program_started")
		set_responsiveness(true)
		return
	if key == "program_stopped":
		running=false
		emit_signal("program_stopped")
		set_responsiveness(false)
		return
	if key == "runtime_data":
		emit_signal("runtime_data_received", data)
		return
		
	prints("ble hub unrecognized data key:", key)

func send_command(command, args, return_id=null):
	# communicator.send_command(name, command, args, return_id)
	emit_signal("ble_command", name, command, args, return_id)

func connect_hub():
	assert(not connected)
	send_command("connect", [])

func disconnect_hub():
	assert(connected)
	send_command("disconnect", [])

func run_program():
	assert(connected and not running)
	send_command("run", [])

func stop_program():
	assert(connected and running)
	send_command("stop_program", [])
	set_responsiveness(false)

func rpc(funcname, args):
	send_command("rpc", [funcname, args])

func remove():
	assert(not connected)
	emit_signal("removing", name)

func connect_coroutine():
	connect_hub()
	yield(self, "connected")

func disconnect_coroutine():
	disconnect_hub()
	yield(self, "disconnected")

func run_program_coroutine():
	run_program()
	yield(self, "program_started")

func stop_program_coroutine():
	stop_program()
	yield(self, "program_stopped")

func clean_exit_coroutine():
	if running:
		yield(stop_program_coroutine(), "completed")
	if connected:
		yield(disconnect_coroutine(), "completed")

func connect_and_run_coroutine():
	if not connected:
		yield(connect_coroutine(), "completed")
		yield(Devices.get_tree().create_timer(0.5), "timeout")
	if not running:
		yield(run_program_coroutine(), "completed")
