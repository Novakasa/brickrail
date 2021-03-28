extends Node2D

var trains = {}
var layout_controllers = {}
var switches = {}

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

func add_switch(p_name, p_controller, p_port):
	var switch = PhysicalSwitch.new(p_name, p_controller, p_port)
	switch.connect("name_changed", self, "_on_switch_name_changed")
	switch.connect("controller_changed", self, "_on_switch_controller_changed")
	switches[p_name] = switch
	if p_controller != null:
		layout_controllers[p_controller].attach_device(switch)

func _on_switch_name_changed(p_old_name, p_name):
	var switch = switches[p_old_name]
	switches.erase(p_old_name)
	switches[p_name] = switch

func _on_switch_controller_changed(p_name, p_old_controller, p_controller):
	var switch = switches[p_name]
	if p_old_controller != null:
		layout_controllers[p_old_controller].remove_device(p_name)
	if p_controller != null:
		layout_controllers[p_controller].attach_device(switch)

func find_device(return_key):
	$BLEController.send_command(null, "find_device", [], return_key)
