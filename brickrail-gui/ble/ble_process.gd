class_name BLEProcess
extends Node

var process_pid

func start_process():
	yield(get_tree(), "idle_frame")
	print("starting python server process")
	var dir = Directory.new()
	var _err = dir.open(".")
	
	if OS.get_name() == "Windows":
		var process_command
		if OS.has_feature("standalone"):
			process_command = ".\\ble-server-windows\\ble_server.exe"
		else:
			# .env is a conda environment
			process_command = "..\\.env\\python.exe ../ble-server/ble_server.py"
		
		process_pid = OS.execute("CMD.exe", ["/K", process_command], false, [], false, true)
	if OS.get_name() == "Linux":
		var process_command
		if OS.has_feature("standalone"):
			process_command = "chmod +x ./ble-server-linux/mpy_cross_v6/mpy-cross && chmod +x ./ble-server-linux/ble_server && ./ble-server-linux/ble_server"
		else:
			# .env is a conda environment
			process_command = "../.env/bin/python ../ble-server/ble_server.py"
		process_pid = OS.execute("gnome-terminal", ["--", "bash", "-c", process_command], false)
	if OS.get_name() == "macOS":
		var process_command
		if OS.has_feature("standalone"):
			process_command = "chmod +x ./ble-server-macos/mpy_cross_v6/mpy-cross && chmod +x ./ble-server-macos/ble_server && ./ble-server-macos/ble_server"
		else:
			# .env is a conda environment
			process_command = "../.env/bin/python ../ble-server/ble_server.py"
		process_pid = OS.execute("osascript", ["-e", 'tell app "Terminal" to do script "'+process_command+'"'], false)
		

	yield(get_tree().create_timer(1.5), "timeout")

	prints("pid:", process_pid)

func kill():
	print("killing python server process")
	var _er = OS.kill(process_pid)
