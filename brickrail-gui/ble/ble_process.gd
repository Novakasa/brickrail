class_name BLEProcess
extends Node

var process_pid

func start_process():
	yield(get_tree(), "idle_frame")
	print("starting python server process")
	var dir = Directory.new()
	var _err = dir.open(".")
	var dist_exists = dir.dir_exists("ble-server-portable")
	
	if dist_exists:
		print("python server dist found!")
	else:
		print("using python environment in ble-server/.env/ if it exists")
	
	if OS.get_name() == "Windows":
		var process_command
		if not dist_exists:
			# .env is a conda environment
			process_command = ".\\ble-server\\.env\\python.exe ble-server/ble_server.py"
		else:
			process_command = ".\\ble-server-portable\\ble_server.exe"
		
		process_pid = OS.execute("CMD.exe", ["/K", process_command], false, [], false, true)
	else:
		var process_command
		if not dist_exists:
			# .env is a venv
			process_command = './ble-server/.env/bin/python ble-server/ble_server.py'
		else:
			# process_command = './dist/ble_server && read line'
			process_command = 'chmod +x ./ble-server-portable/mpy_cross_v6/mpy-cross && chmod +x ./ble-server-portable/ble_server && ./ble-server-portable/ble_server && read line'
			# process_command = "./ble-server-portable/ble_server && read line"
		process_pid = OS.execute("gnome-terminal", ['--', 'bash', '-c', process_command], false)
		yield(get_tree().create_timer(1.5), "timeout")
	# bash", "-c", "./ble-server/.env/bin/python", "ble-server/ble_server.py"], false, [], false, true)
	prints("pid:", process_pid)

func kill():
	print("killing python server process")
	var _er = OS.kill(process_pid)
