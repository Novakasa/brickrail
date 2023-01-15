extends Control

export(NodePath) var layout
export(NodePath) var train_controller_container
export(NodePath) var layout_controller_container

onready var TrainControllerGUI = preload("res://devices/train/train_control_gui.tscn")
onready var LayoutControllerGUI = preload("res://devices/layout_controller/layout_controller_gui.tscn")

func _ready():
	get_tree().set_auto_accept_quit(false)
	Devices.connect("train_added", self, "_on_devices_train_added")
	Devices.connect("layout_controller_added", self, "_on_devices_layout_controller_added")

func _on_devices_data_received(_key, _data):
	pass

func _on_devices_train_added(p_name):
	var train_controller_gui = TrainControllerGUI.instance()
	train_controller_gui.setup(p_name)
	get_node(train_controller_container).add_child(train_controller_gui)

func _on_devices_layout_controller_added(p_name):
	var layout_controller_gui = LayoutControllerGUI.instance()
	layout_controller_gui.setup(p_name)
	get_node(layout_controller_container).add_child(layout_controller_gui)

func _on_AddTrainButton_pressed():
	var trainnum = len(Devices.trains)
	var trainname = "train"+str(trainnum)
	Devices.add_train(trainname)

func _on_AddLayoutControllerButton_pressed():
	var controllernum = len(Devices.layout_controllers)
	var controllername = "controller"+str(controllernum)
	Devices.add_layout_controller(controllername)

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		print("manual quit!")
		yield(Devices.get_ble_controller().clean_exit_coroutine(), "completed")
		get_tree().quit()

func _on_ConnectAllButton_pressed():
	yield(Devices.get_ble_controller().connect_and_run_all_coroutine(), "completed")

func _on_DisconnectAllButton_pressed():
	yield(Devices.get_ble_controller().disconnect_all_coroutine(), "completed")
