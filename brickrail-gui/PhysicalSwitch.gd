class_name PhysicalSwitch
extends Reference

var name
var port
var controller

signal hub_command(cmd)
signal name_changed(p_old_name, p_name)
signal controller_changed(p_old_controller, p_controller)

func _init(p_name, p_controller, p_port):
	name = p_name
	port = p_port
	controller = p_controller

func setup_on_hub():
	var cmd = "controller.add_device(Switch('"+name+"', "+str(port)+"))"
	emit_signal("hub_command", cmd)

func switch(position):
	var cmd = "controller.devices["+self.name+"].switch("+position+")"
	emit_signal("hub_command", cmd)

func set_name(p_name):
	var old_name = name
	name = p_name
	emit_signal("name_changed", old_name, name)

func set_controller(p_controller):
	var old_controller = controller
	controller = p_controller
	emit_signal("controller_changed", name, old_controller, controller)

func set_port(p_port):
	port = p_port
