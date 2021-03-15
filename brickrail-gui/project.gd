extends Node2D

var trains: Dictionary
var Train = preload("res://train.tscn")

func add_train(name, address=null):
	var train = Train.instance()
	train.ble_communicator = $BLECommunicator
	train.name = name
	train.address = address
	self.trains[name] = train
	train.ble_add()
