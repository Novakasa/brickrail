class_name PhysicalSwitch
extends Reference

var name
var port
var controller

func _init(p_name, p_port, p_controller):
	name = p_name
	port = p_port
	controller = p_controller
	if controller.is_running():
		setup_on_hub()

func setup_on_hub():
	var cmd = "controller.add_device(Switch("+name+", "+", "+port+"))"
	controller.hub.hub_command(cmd)

func switch(position):
	assert(controller.is_running())
	var cmd = "controller.devices["+self.name+"].switch("+position+")"
	controller.hub.hub_command(cmd)
