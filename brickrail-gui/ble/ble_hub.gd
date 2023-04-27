class_name BLEHub
extends Reference

var program
var name
var connected = false
var running = false
var communicator: BLECommunicator
var responsiveness = false
var busy = false
var status = "disconnected"
var battery_voltage = -1.0
var battery_current = -1.0

var storage = {}

signal runtime_data_received(data)
signal ble_command(hub, command, args, return_id)
signal name_changed(p_name, p_new_name)
signal connected()
signal disconnected()
signal connect_error()
signal program_started()
signal program_stopped()
signal program_error(data)
signal program_start_error()
signal responsiveness_changed(value)
signal removing(name)
signal state_changed()
signal battery_changed()

func _init(p_name, p_program):
	name = p_name
	program = p_program
	communicator = Devices.get_ble_controller().get_node("BLECommunicator")
	var _err = communicator.connect("status_changed", self, "_on_ble_communicator_status_changed")

func _on_ble_communicator_status_changed():
	if not communicator.connected:
		connected = false
		busy = false
		status = "disconnected"
		responsiveness = false
		running = false
		emit_signal("responsiveness_changed", "responsiveness")
		emit_signal("state_changed")

	#TODO: if process is started only now, add hub to ble server state!!!

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
		busy=false
		status = "connected"
		emit_signal("connected")
		emit_signal("state_changed")
		return
	if key == "disconnected":
		connected=false
		busy=false
		status = "disconnected"
		set_responsiveness(false)
		emit_signal("disconnected")
		emit_signal("state_changed")
		return
	if key == "connect_error":
		connected=false
		busy=false
		status = "disconnected"
		GuiApi.show_error("["+name+"] Connection error!")
		emit_signal("connect_error")
		emit_signal("state_changed")
		return
	if key == "program_started":
		running=true
		busy=false
		status = "running"
		set_responsiveness(true)
		emit_signal("program_started")
		emit_signal("state_changed")
		send_storage()
		return
	if key == "program_stopped":
		running=false
		busy=false
		status = "connected"
		set_responsiveness(false)
		emit_signal("program_stopped")
		emit_signal("state_changed")
		return
	if key == "program_error":
		GuiApi.show_error("Hub '"+name+"' Program Error:" + data)
		if "Unexpected Marker" in data:
			LayoutInfo.emergency_stop()
		emit_signal("program_error", data)
		emit_signal("program_start_error")
		return
	if key == "runtime_data":
		emit_signal("runtime_data_received", data)
		return
	if key == "battery":
		battery_current = float(data.current)/1000.0
		battery_voltage = float(data.voltage)/1000.0
		emit_signal("battery_changed")
		return
		
	prints("ble hub unrecognized data key:", key)

func send_storage():
	for i in storage:
		store_value(i, storage[i])

func send_command(command, args, return_id=null):
	# communicator.send_command(name, command, args, return_id)
	emit_signal("ble_command", name, command, args, return_id)

func connect_hub():
	assert(not connected)
	send_command("connect", [])
	busy=true
	status = "connecting"
	emit_signal("state_changed")

func disconnect_hub():
	assert(connected)
	send_command("disconnect", [])
	busy=true
	status = "disconnecting"
	emit_signal("state_changed")

func run_program():
	assert(connected and not running)
	send_command("run", [])
	status = "starting program"
	busy=true
	emit_signal("state_changed")

func stop_program():
	assert(connected and running)
	send_command("stop_program", [])
	set_responsiveness(false)
	status = "stopping program"
	busy=true
	running = false
	emit_signal("state_changed")

func rpc(funcname, args):
	send_command("rpc", [funcname, args])

func store_value(address, value):
	storage[address] = value
	if running:
		send_command("store_value", [address, value])

func remove():
	assert(not connected)
	emit_signal("removing", name)

func safe_remove_coroutine():
	if not connected:
		yield(Devices.get_tree(), "idle_frame")
	if running:
		yield(stop_program_coroutine(), "completed")
	if connected:
		yield(disconnect_coroutine(), "completed")
	remove()

func connect_coroutine():
	connect_hub()
	var first_signal = yield(Await.first_signal(self, ["connected", "connect_error"]), "completed")
	if first_signal == "connect_error":
		return "error"
	return "success"

func disconnect_coroutine():
	disconnect_hub()
	yield(self, "disconnected")

func run_program_coroutine():
	run_program()
	var first_signal = yield(Await.first_signal(self, ["program_started", "program_start_error"]), "completed")
	if first_signal == "program_error":
		return "error"
	return "success"

func stop_program_coroutine():
	stop_program()
	yield(self, "program_stopped")
