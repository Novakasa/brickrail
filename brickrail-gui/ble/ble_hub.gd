class_name BLEHub
extends Reference

var program
var skip_download = false
var name
var connected = false
var running = false
var communicator: BLECommunicator
var responsiveness = false
var busy = false
var status = "disconnected"
var battery_voltage = -1.0
var battery_current = -1.0
var active = false

var storage = {}

var logging_module

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
signal skip_download_changed(value)
signal active_changed(p_active)

func set_skip_download(value):
	skip_download = value
	emit_signal("skip_download_changed", value)

func _init(p_name, p_program):
	name = p_name
	program = p_program
	communicator = Devices.get_ble_controller().get_node("BLECommunicator")
	var _err = communicator.connect("status_changed", self, "_on_ble_communicator_status_changed")
	_err = connect("state_changed", self, "_on_state_changed")
	logging_module = "hub-"+name
	set_skip_download(true)
	if name in Settings.hub_program_hashes:
		Logger.info("[%s] hash found in settings" % logging_module)
		if Settings.hub_program_hashes[name] == HubPrograms.hashes[program]:
			Logger.info("[%s] hash is the same, setting skip download" % logging_module)
		else:
			GuiApi.show_info("[%s] Program outdated, program will be redownloaded" % name)
			set_skip_download(false)
	else:
		GuiApi.show_info("[%s] New hub, program will be downloaded" % name)
		set_skip_download(false)
	
	if name in Settings.hub_io_hub_hashes:
		Logger.info("[%s] io_hub hash found in settings" % logging_module)
		if Settings.hub_io_hub_hashes[name] == HubPrograms.hashes["io_hub"]:
			Logger.info("[%s] io_hub hash is the same, setting skip download" % logging_module)
		else:
			GuiApi.show_info("[%s] io_hub outdated, program will be redownloaded" % name)
			set_skip_download(false)
	else:
		GuiApi.show_info("[%s] New hub, program will be downloaded" % name)
		set_skip_download(false)

func _on_state_changed():
	if busy:
		GuiApi.show_info("[%s] %s..." % [name, status])
	else:
		GuiApi.show_info("[%s] %s" % [name, status])

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

func set_active(p_active):
	active = p_active
	emit_signal("active_changed", p_active)
	emit_signal("state_changed")
	
	if not active:
		if running:
			yield(stop_program_coroutine(), "completed")
		if connected:
			yield(disconnect_coroutine(), "completed")
	
func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	emit_signal("name_changed", old_name, p_new_name)

func _on_data_received(key, data):
	if key == "connected":
		connected=true
		busy=false
		status = "connected"
		emit_signal("state_changed")
		emit_signal("connected")
		return
	if key == "disconnected":
		connected=false
		busy=false
		status = "disconnected"
		set_responsiveness(false)
		emit_signal("state_changed")
		emit_signal("disconnected")
		return
	if key == "connect_error":
		connected=false
		busy=false
		status = "disconnected"
		var msg = "["+name+"] Connection error!"
		var more_info = msg
		more_info += "\nIs the hub turned on?"
		more_info += "\nIs pybricks installed on the hub?"
		more_info += "\nIs the name consistent with the name given during pybricks installation?"
		GuiApi.show_error(msg, more_info)
		emit_signal("state_changed")
		emit_signal("connect_error")
		return
	if key == "program_started":
		
		if not skip_download:
			Settings.hub_program_hashes[name] = HubPrograms.hashes[program]
			Settings.hub_io_hub_hashes[name] = HubPrograms.hashes["io_hub"]
			set_skip_download(true)
		
		running=true
		busy=false
		status = "running"
		set_responsiveness(true)
		emit_signal("state_changed")
		emit_signal("program_started")
		send_storage()
		return
	if key == "program_stopped":
		running=false
		busy=false
		status = "connected"
		set_responsiveness(false)
		emit_signal("state_changed")
		emit_signal("program_stopped")
		return
	if key == "program_error":
		if status == "starting program":
			emit_signal("program_start_error")
			set_skip_download(false)
			if "ENODEV" in data:
				var msg = "Hub '"+name+"' missing motor or sensor!"
				var more_info = msg
				more_info += "\n\nFor trains:"
				more_info += "\nThe motor needs to be plugged into Port A"
				more_info += "\nThe Color and Distance sensor needs to be plugged into Port B"
				more_info += "\n\nFor Layout controllers:"
				more_info += "\nmake sure each switch is configured correctly!"
				GuiApi.show_error(msg, more_info)
			else:
				var msg = "Hub '"+name+"' Program start Error: " + data
				var more_info = msg
				more_info += "\nIs the correct pybricks firmware installed?"
				GuiApi.show_error(msg, more_info)
		else:
			if data == "program_start_timeout":
				return
			elif "ENODEV" in data:
				GuiApi.show_error("Hub '"+name+"' missing motor or sensor!")
			else:
				GuiApi.show_error("Hub '"+name+"' Program Error: " + data)
			emit_signal("program_error", data)
		
		# REVISIT: This may be needed in case the program_stopped notification never arrives?
		running=false
		busy=false
		status = "connected"
		emit_signal("state_changed")
		return
	if key == "runtime_data":
		emit_signal("runtime_data_received", PoolIntArray(data)) 
		return
	if key == "battery":
		battery_current = float(data.current)/1000.0
		battery_voltage = float(data.voltage)/1000.0
		emit_signal("battery_changed")
		return
	if key == "info":
		GuiApi.show_info(data[0], data[1])
		return
		
	Logger.error("[%s] Unrecognized data key: %s data: %s" % [logging_module, key, data])

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
	send_command("brickrail_run", [skip_download])
	status = "downloading and starting program"
	if skip_download:
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
	if first_signal == "program_start_error":
		return "error"
	return "success"

func stop_program_coroutine():
	stop_program()
	yield(self, "program_stopped")
