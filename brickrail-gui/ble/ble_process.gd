class_name BLEProcess
extends Node

func start_process():
	OS.execute("start", ["cmd"], false)
