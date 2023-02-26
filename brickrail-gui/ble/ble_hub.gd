class_name BLEHub
extends Reference

var program
var name
var connected = false
var running = false
var communicator: BLECommunicator
var responsiveness = false
var busy = false

signal runtime_data_received(data)
signal ble_command(hub, command, args, return_id)
signal name_changed(p_name, p_new_name)
signal connected
signal disconnected
signal connect_error()
signal program_started
signal program_stopped
signal responsiveness_changed(value)
signal removing(name)
signal state_changed()

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
		busy=false
		emit_signal("state_changed")
		return
	if key == "disconnected":
		connected=false
		emit_signal("disconnected")
		set_responsiveness(false)
		busy=false
		emit_signal("state_changed")
		return
	if key == "connect_error":
		connected=false
		emit_signal("connect_error")
		busy=false
		emit_signal("state_changed")
		return
	if key == "program_started":
		running=true
		emit_signal("program_started")
		set_responsiveness(true)
		busy=false
		emit_signal("state_changed")
		return
	if key == "program_stopped":
		running=false
		emit_signal("program_stopped")
		set_responsiveness(false)
		busy=false
		emit_signal("state_changed")
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
	busy=true
	emit_signal("state_changed")

func disconnect_hub():
	assert(connected)
	send_command("disconnect", [])
	busy=true
	emit_signal("state_changed")

func run_program():
	assert(connected and not running)
	send_command("run", [])
	busy=true
	emit_signal("state_changed")

func stop_program():
	assert(connected and running)
	send_command("stop_program", [])
	set_responsiveness(false)
	busy=true
	emit_signal("state_changed")

func rpc(funcname, args):
	send_command("rpc", [funcname, args])

func remove():
	assert(not connected)
	emit_signal("removing", name)

func connect_coroutine():
	GuiApi.status_process("Connecting hub "+name+"...")
	connect_hub()
	var first_signal = yield(Await.first_signal(self, ["connected", "connect_error"]), "completed")
	if first_signal == "connect_error":
		GuiApi.show_error("Connection error!")
		GuiApi.status_ready()
		return "error"
	GuiApi.status_ready()
	return "success"

func disconnect_coroutine():
	GuiApi.status_process("Disconnecting hub "+name+"...")
	disconnect_hub()
	yield(self, "disconnected")
	GuiApi.status_ready()

func run_program_coroutine():
	GuiApi.status_process("Hub "+name+" starting program...")
	run_program()
	yield(self, "program_started")
	GuiApi.status_ready()

func stop_program_coroutine():
	GuiApi.status_process("Hub "+name+" stopping program...")
	stop_program()
	yield(self, "program_stopped")
	GuiApi.status_ready()

