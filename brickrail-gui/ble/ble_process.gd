class_name BLEProcess
extends Node

var process_pid
var logging_module = "BLEProcess"

func start_process():
	await get_tree().process_frame
	Logger.info("[%s] Starting BLEServer process" % [logging_module])
	
	if OS.get_name() == "Windows":
		var process_command
		if OS.has_feature("standalone"):
			Logger.info("[%s] starting windows ble_server.exe" % [logging_module])
			process_command = ".\\ble-server-windows\\ble_server.exe"
		else:
			# .env is a conda environment
			Logger.info("[%s] starting windows ble_server.py" % [logging_module])
			process_command = "..\\.env\\python.exe ../ble-server/ble_server.py"
		
		process_pid = OS.create_process("CMD.exe", ["/K", process_command], true)
	else:
		var process_command
		if OS.has_feature("standalone"):
			Logger.info("[%s] starting linux ble_server binary" % [logging_module])
			process_command = "chmod +x ./ble-server-linux/mpy_cross_v6/mpy-cross && chmod +x ./ble-server-linux/ble_server && ./ble-server-linux/ble_server"
		else:
			# .env is a conda environment
			Logger.info("[%s] starting linux ble_server.py" % [logging_module])
			process_command = "../.env/bin/python ../ble-server/ble_server.py"
		process_pid = OS.create_process("gnome-terminal", ["--", "bash", "-c", process_command], false)

	await get_tree().create_timer(1.5).timeout

	Logger.info("[%s] Process started with pid: %s" % [logging_module, process_pid])

func kill():
	Logger.info("[%s] Killing BLEServer process" % [logging_module])
	var _er = OS.kill(process_pid)
