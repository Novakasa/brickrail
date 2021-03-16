extends Node2D

var address = null
var ble_communicator

func ble_connect():
	# var command = 'await project.hubs["' + name + '"].connect()'
	ble_communicator.send_command(name, "connect", [], null)

func ble_add():
	var script_path = "E:/repos/brickrail/autonomous_train.py"
	ble_communicator.send_command(null, "add_hub", [name, script_path, address], null)

func ble_run():
	# var command = "await project.hubs['" + name + "'].run()"
	ble_communicator.send_command(name, "run", [], null)

func ble_start():
	ble_communicator.send_command(name, "pipe_command", ["train.start()"], null)
