class_name BLEProcess
extends Node

var process_pid

func start_process():
	yield(get_tree(), "idle_frame")
	print("starting python server process")
	if OS.get_name() == "windows":
		process_pid = OS.execute("CMD.exe", ["/K", "ble-server\\.env\\python.exe", "ble-server/ble_server.py"], false, [], false, true)
	else:
		process_pid = OS.execute("gnome-terminal", ['--', 'bash', '-c', './ble-server/.env/bin/python ble-server/ble_server.py'], false)
		yield(get_tree().create_timer(0.5), "timeout")
	# bash", "-c", "./ble-server/.env/bin/python", "ble-server/ble_server.py"], false, [], false, true)
	prints("pid:", process_pid)

func kill():
	print("killing python server process")
	var _er = OS.kill(process_pid)
