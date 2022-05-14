class_name BLEProcess
extends Node

func start_process():
	OS.execute("CMD.exe", ["/C", "cd .. && ble-server\\.env\\python.exe ble-server/ble_server.py"], false)
