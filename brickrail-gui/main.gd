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
	Devices.connect("train_added", self, "_on_devices_train_added")
	Devices.connect("switch_added", self, "_on_devices_switch_added")
	Devices.connect("layout_controller_added", self, "_on_devices_layout_controller_added")

func _on_devices_data_received(key, data):
	pass

func _on_AddTrain_pressed():
	var trainnum = len(Devices.trains)
	var trainname = "train"+str(trainnum)
	Devices.add_train(trainname, null)
	
func _on_AddLayoutController_pressed():
	var controllernum = len(Devices.layout_controllers)
	var controllername = "controller"+str(controllernum)
	Devices.add_layout_controller(controllername, null)

func _on_AddSwitch_pressed():
	var switchnum = len(Devices.switches)
	var switchname = "switch"+str(switchnum)
	Devices.add_switch(switchname, null, null)

func _on_devices_train_added(p_name):
	var train_controller_gui = TrainControllerGUI.instance()
	train_controller_gui.setup(p_name)
	get_node(train_controller_container).add_child(train_controller_gui)

func _on_devices_layout_controller_added(p_name):
	var layout_controller_gui = LayoutControllerGUI.instance()
	layout_controller_gui.setup(p_name)
	get_node(layout_controller_container).add_child(layout_controller_gui)

func _on_devices_switch_added(p_name):
	var switch_gui = SwitchGUI.instance()
	switch_gui.setup(p_name)
	get_node(switch_container).add_child(switch_gui)

func _on_Devices_data_received(key, data):
	pass


func _on_LayoutSelect_pressed():
	pass # Replace with function body.


func _on_LayoutDraw_pressed():
	pass # Replace with function body.
