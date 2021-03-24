extends Control

export(NodePath) var project
export(NodePath) var train_controller_container

onready var TrainControllerGUI = preload("res://train_control_gui.tscn")

func _on_AddTrain_pressed():
	$AddTrainDialog.popup_centered()
	
func add_train(p_name, p_address):
	var train_controller_gui = TrainControllerGUI.instance()
	train_controller_gui.train = p_name
	get_node(train_controller_container).add_child(train_controller_gui)
	train_controller_gui.connect("train_action", self, "_on_train_action")
	get_node(project).add_train(p_name, p_address)

func _on_AddTrainDialog_add_train(p_name, p_address):
	add_train(p_name, p_address)

func _on_train_action(action):
	print("[main] forwarding train action")
	get_node(project).commit_action(action)


func _on_Project_data_received(key, data):
	prints("[main] data received", key, data)
	if key == "find_device_address":
		var address = data
		$AddTrainDialog.insert_address(address)


func _on_AddTrainDialog_scan_device():
	get_node(project).find_device()
