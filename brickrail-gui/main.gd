extends Control

export(NodePath) var project
export(NodePath) var train_controller_container
export(NodePath) var layout_controller_container
export(NodePath) var switch_container

onready var TrainControllerGUI = preload("res://train_control_gui.tscn")
onready var LayoutControllerGUI = preload("res://layout_controller_gui.tscn")
onready var SwitchGUI = preload("res://switch_gui.tscn")

func _on_AddTrain_pressed():
	var trainnum = len(get_node(project).trains)
	var trainname = "train"+str(trainnum)
	add_train(trainname, null)
	
func _on_AddLayoutController_pressed():
	var controllernum = len(get_node(project).layout_controllers)
	var controllername = "controller"+str(controllernum)
	add_layout_controller(controllername, null)

func _on_AddSwitch_pressed():
	var switchnum = len(get_node(project).switches)
	var switchname = "switch"+str(switchnum)
	add_switch(switchname, null, null)

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

func add_switch(p_name, p_controller, p_port):
	var switch_gui = SwitchGUI.instance()
	get_node(project).add_switch(p_name, p_controller, p_port)
	switch_gui.setup(get_node(project), p_name)
	get_node(switch_container).add_child(switch_gui)

func _on_Project_data_received(key, data):
	pass
