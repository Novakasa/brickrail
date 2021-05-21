extends Control

export(NodePath) var layout
export(NodePath) var train_controller_container
export(NodePath) var layout_controller_container
export(NodePath) var switch_container

onready var TrainControllerGUI = preload("res://train_control_gui.tscn")
onready var LayoutControllerGUI = preload("res://layout_controller_gui.tscn")
onready var SwitchGUI = preload("res://switch_gui.tscn")

func _ready():
	Devices.connect("data_received", self, "_on_devices_data_received")

func _on_AddTrain_pressed():
	var trainnum = len(Devices.trains)
	var trainname = "train"+str(trainnum)
	add_train(trainname, null)
	
func _on_AddLayoutController_pressed():
	var controllernum = len(Devices.layout_controllers)
	var controllername = "controller"+str(controllernum)
	add_layout_controller(controllername, null)

func _on_AddSwitch_pressed():
	var switchnum = len(Devices.switches)
	var switchname = "switch"+str(switchnum)
	add_switch(switchname, null, null)

func add_train(p_name, p_address):
	var train_controller_gui = TrainControllerGUI.instance()
	Devices.add_train(p_name, p_address)
	train_controller_gui.setup(p_name)
	get_node(train_controller_container).add_child(train_controller_gui)

func add_layout_controller(p_name, p_address):
	var layout_controller_gui = LayoutControllerGUI.instance()
	Devices.add_layout_controller(p_name, p_address)
	layout_controller_gui.setup(p_name)
	get_node(layout_controller_container).add_child(layout_controller_gui)

func add_switch(p_name, p_controller, p_port):
	var switch_gui = SwitchGUI.instance()
	Devices.add_switch(p_name, p_controller, p_port)
	switch_gui.setup(p_name)
	get_node(switch_container).add_child(switch_gui)

func _on_Devices_data_received(key, data):
	pass

func _on_ViewportContainer_mouse_entered():
	get_node(layout).get_node("Grid").mouse_focus = true

func _on_ViewportContainer_mouse_exited():
	get_node(layout).get_node("Grid").mouse_focus = false
