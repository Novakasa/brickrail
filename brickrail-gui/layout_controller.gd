class_name LayoutController
extends Reference

var name
var hub
var devices = {}
var connected = false
var running = false

signal name_changed(p_name, p_new_name)

func _init(p_name, p_address):
	name = p_name
	hub = BLEHub.new(p_name, "layout_controller", p_address)
	hub.connect("data_received", self, "_on_data_received")

func _on_data_received(key, data):
	if key == "device_data":
		var devkey = data.key
		var devname = data.device
		var devdata = data.data
		devices[devname]._on_data_received(devkey, devdata)

func set_name(p_new_name):
	var old_name = name
	name = p_new_name
	hub.set_name(p_new_name)
	emit_signal("name_changed", old_name, p_new_name)

func set_address(p_address):
	hub.set_address(p_address)

func connect_hub():
	hub.connect_hub()
	connected = true

func run_program():
	assert(connected)
	hub.run_program()
	running = true
	for device in self.devices.values():
		device.setup_on_hub()

func attach_device(device):
	device.controller = self
	assert(device.port <= 3)
	devices[device.name] = device

func attached_ports():
	var ports = []
	for device in devices.values():
		ports.append(device.port)
