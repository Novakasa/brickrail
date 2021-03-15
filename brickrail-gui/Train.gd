extends Node2D

var address = null
var ble_communicator

func ble_connect():
	var command = 'await project.hubs["' + name + '"].connect()'
	ble_communicator.send_command(command)

func ble_add():
	var addressstr = address
	if addressstr == null:
		addressstr = "None"
	var command = "project.add_hub('" + name + "', 'autonomous_train.py', " + addressstr + ")"
	ble_communicator.send_command(command)

func ble_run():
	var command = "await project.hubs['" + name + "'].run()"
	ble_communicator.send_command(command)
