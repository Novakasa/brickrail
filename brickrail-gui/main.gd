extends Control

export(NodePath) var project
export(NodePath) var train_controller_container
export(NodePath) var layout_controller_container

onready var TrainControllerGUI = preload("res://train_control_gui.tscn")
onready var LayoutControllerGUI = preload("res://layout_controller_gui.tscn")

func _on_AddTrain_pressed():
	var trainnum = len(get_node(project).trains)
	var trainname = "train"+str(trainnum)
	add_train(trainname, null)
	
func _on_AddLayoutController_pressed():
	var controllernum = len(get_node(project).trains)
	var controllername = "controller"+str(controllernum)
	add_layout_controller(controllername, null)

func add_train(p_name, p_address):
	var train_controller_gui = TrainControllerGUI.instance()
	get_node(project).add_train(p_name, p_address)
	train_controller_gui.setup(get_node(project), p_name)
	get_node(train_controller_container).add_child(train_controller_gui)

func add_layout_controller(p_name, p_address):
	var layout_controller_gui = LayoutControllerGUI.instance()
	get_node(project).add_layout_controller(p_name, p_address)
	layout_controller_gui.setup(get_node(project), p_name)
	get_node(layout_controller_container).add_child(layout_controller_gui)

func _on_train_action(action):
	print("[main] forwarding train action")
	get_node(project).commit_action(action)


func _on_Project_data_received(key, data):
	pass
