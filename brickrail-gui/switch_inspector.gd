extends Panel

var switch
export(NodePath) var device1_option
export(NodePath) var device2_option

func set_switch(p_switch):
	switch = p_switch
	switch.connect("unselected", self, "_on_switch_unselected")

func _on_switch_unselected():
	queue_free()

func _ready():
	set_device_labels()

func set_device_labels():
	var option1 = get_node(device1_option)
	var option2 = get_node(device2_option)
	for option in [option1, option2]:
		option.clear()
		option.add_item("None")
		for ble_switch in Devices.switches.values():
			option.add_item(ble_switch.name)
	
	if switch.ble_switch != null:
		option1.select(Devices.switches.keys().find(switch.ble_switch.name)+1)
	else:
		option1.select(0)
		

func _on_Device2Option_item_selected(index):
	pass


func _on_Device1Option_item_selected(index):
	switch.set_ble_switch(Devices.switches.values()[index-1])
