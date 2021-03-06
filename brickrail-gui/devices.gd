extends Node2D

var trains = {}
var layout_controllers = {}
var switches = {}
var colors = {}

signal data_received(key,data)
signal trains_changed
signal train_added(trainname)
signal layout_controller_added(p_name)
signal switch_added(p_name)
signal layout_controllers_changed
signal switches_changed

signal color_added(p_colorname)
signal color_removed(p_colorname)

func _on_data_received(key, data):
	prints("[project] received data", key, data)
	emit_signal("data_received", key, data)

func serialize():
	var struct = {}
	
	var colordata = []
	for color in colors.values():
		colordata.append(color.serialize())
	struct["colors"] = colordata
	
	var traindata = []
	for train in trains.values():
		traindata.append(train.serialize())
	struct["trains"] = traindata

	var controllerdata = []
	for controller in layout_controllers.values():
		controllerdata.append(controller.serialize())
	struct["controllers"] = controllerdata
	
	var switchdata = []
	for switch in switches.values():
		switchdata.append(switch.serialize())
	struct["switches"] = switchdata
	
	return struct

func load(struct):
	for color_data in struct.colors:
		var color = create_color(color_data.colorname, color_data.type)
		color.load(color_data)
	
	for train_data in struct.trains:
		var train = add_train(train_data.name, train_data.address)
		# train.load(train_data)
	
	for controller_data in struct.controllers:
		var controller = add_layout_controller(controller_data.name, controller_data.address)
		# controller.load(controller_data)
	
	for switch_data in struct.switches:
		var switch = add_switch(switch_data.name, switch_data.controller, switch_data.port)
		# switch.load(switch_data)

func create_color(colorname, type):
	var color = load("res://calibrated_color.tscn").instance()
	color.connect("removing", self, "_on_color_removing")
	color.setup(colorname, type)
	colors[colorname] = color
	emit_signal("color_added", colorname)
	return color

func _on_color_removing(colorname):
	colors.erase(colorname)
	emit_signal("color_removed", colorname)

func add_train(p_name, p_address=null):
	var train = BLETrain.new(p_name, p_address)
	get_node("BLEController").add_hub(train.hub)
	trains[p_name] = train
	train.connect("name_changed", self, "_on_train_name_changed")
	emit_signal("trains_changed")
	emit_signal("train_added", p_name)
	return train

func _on_train_name_changed(p_name, p_new_name):
	var train = trains[p_name]
	trains.erase(p_name)
	trains[p_new_name] = train
	emit_signal("trains_changed")

func add_layout_controller(p_name, p_address=null):
	var controller = LayoutController.new(p_name, p_address)
	$BLEController.add_hub(controller.hub)
	layout_controllers[p_name] = controller
	controller.connect("name_changed", self, "_on_controller_name_changed")
	emit_signal("layout_controllers_changed")
	emit_signal("layout_controller_added", p_name)
	return controller

func _on_controller_name_changed(p_name, p_new_name):
	var controller = layout_controllers[p_name]
	layout_controllers.erase(p_name)
	layout_controllers[p_new_name] = controller
	emit_signal("layout_controllers_changed")

func add_switch(p_name, p_controller, p_port):
	var switch = PhysicalSwitch.new(p_name, p_controller, p_port)
	switch.connect("name_changed", self, "_on_switch_name_changed")
	switch.connect("controller_changed", self, "_on_switch_controller_changed")
	switches[p_name] = switch
	if p_controller != null:
		layout_controllers[p_controller].attach_device(switch)
	emit_signal("switches_changed")
	emit_signal("switch_added", p_name)
	return switch

func _on_switch_name_changed(p_old_name, p_name):
	var switch = switches[p_old_name]
	switches.erase(p_old_name)
	switches[p_name] = switch
	emit_signal("switches_changed")

func _on_switch_controller_changed(p_name, p_old_controller, p_controller):
	var switch = switches[p_name]
	if p_old_controller != null:
		layout_controllers[p_old_controller].remove_device(p_name)
	if p_controller != null:
		layout_controllers[p_controller].attach_device(switch)

func find_device(return_key):
	$BLEController.send_command(null, "find_device", [], return_key)
