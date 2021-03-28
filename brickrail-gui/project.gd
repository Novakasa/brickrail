extends Node2D

var trains = {}
var layout_controllers = {}

signal data_received(key,data)

func _on_data_received(key, data):
	prints("[project] received data", key, data)
	emit_signal("data_received", key, data)

func add_train(p_name, p_address=null):
	var train = BLETrain.new(p_name, p_address)
	get_node("BLEController").add_hub(train.hub)
	trains[p_name] = train
	train.connect("name_changed", self, "_on_train_name_changed")

func _on_train_name_changed(p_name, p_new_name):
	var train = trains[p_name]
	trains.erase(p_name)
	trains[p_new_name] = train

func add_layout_controller(p_name, p_address=null):
	var controller = LayoutController.new(p_name, p_address)
	$BLEController.add_hub(controller.hub)
	layout_controllers[p_name] = controller
	controller.connect("name_changed", self, "_on_controller_name_changed")

func _on_controller_name_changed(p_name, p_new_name):
	var controller = layout_controllers[p_name]
	layout_controllers.erase(p_name)
	layout_controllers[p_new_name] = controller

func find_device(return_key):
	$BLEController.send_command(null, "find_device", [], return_key)
