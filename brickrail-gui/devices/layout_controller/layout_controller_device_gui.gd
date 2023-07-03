extends HBoxContainer


var port

signal device_selected(p_port, p_type)

func setup(p_port):
	port = p_port
	$DeviceOption.set_items(["Switch", "Crossing"], ["switch_motor", "crossing_motor"])
	$PortLabel.text = ["A", "B", "C", "D", "E", "F"][port]

func _on_DeviceOption_meta_selected(meta):
	emit_signal("device_selected", port, meta)

func select_device(type):
	$DeviceOption.select_meta(type)
