extends Control

@export var layout: NodePath
@export var train_controller_container: NodePath
@export var layout_controller_container: NodePath
@export var connect_all_button: NodePath
@export var disconnect_all_button: NodePath
@export var connect_ble_server_button: NodePath
@export var add_train_hub_button: NodePath
@export var add_controller_hub_button: NodePath

@onready var TrainControllerGUI = preload("res://devices/train/train_control_gui.tscn")
@onready var LayoutControllerGUI = preload("res://devices/layout_controller/layout_controller_gui.tscn")

func _ready():
	Logger.set_logger_format(Logger.LOG_FORMAT_MORE)
	Logger.set_logger_level(Logger.LOG_LEVEL_INFO)
	get_tree().set_auto_accept_quit(false)
	var _err = Devices.connect("train_added", Callable(self, "_on_devices_train_added"))
	_err = Devices.connect("layout_controller_added", Callable(self, "_on_devices_layout_controller_added"))
	_err = Devices.get_ble_controller().connect("hubs_state_changed", Callable(self, "_on_hubs_state_changed"))

func _on_hubs_state_changed():
	var enabled = Devices.get_ble_controller().hub_control_enabled
	get_node(connect_all_button).disabled = not enabled
	get_node(disconnect_all_button).disabled = not enabled
	
	var communicator = Devices.get_ble_controller().get_node("BLECommunicator")
	get_node(connect_ble_server_button).disabled = communicator.busy or communicator.connected
	# get_node(add_train_hub_button).disabled = communicator.busy or (not communicator.connected)
	# get_node(add_controller_hub_button).disabled = communicator.busy or (not communicator.connected)

func _on_devices_train_added(p_name):
	var train_controller_gui = TrainControllerGUI.instantiate()
	train_controller_gui.setup(p_name)
	get_node(train_controller_container).add_child(train_controller_gui)

func _on_devices_layout_controller_added(p_name):
	var layout_controller_gui = LayoutControllerGUI.instantiate()
	layout_controller_gui.setup(p_name)
	get_node(layout_controller_container).add_child(layout_controller_gui)

func _on_AddTrainButton_pressed():
	var trainnum = len(Devices.trains)
	var train_id = "train"+str(trainnum)
	Devices.add_train(train_id)

func _on_AddLayoutControllerButton_pressed():
	var controllernum = len(Devices.layout_controllers)
	var controllername = "controller"+str(controllernum)
	Devices.add_layout_controller(controllername)

func _on_ConnectAllButton_pressed():
	await Devices.get_ble_controller().connect_and_run_all_coroutine().completed

func _on_DisconnectAllButton_pressed():
	await Devices.get_ble_controller().disconnect_all_coroutine().completed

func _on_ConnectBLEServerButton_pressed():
	await Devices.get_ble_controller().setup_process_and_sync_hubs().completed
