extends Panel

var train_name
export(NodePath) var train_label
export(NodePath) var control_container
export(NodePath) var hub_controls

var markers = ["blue_marker", "red_marker"]
var modes = ["block", "auto", "manual"]

func setup(p_train_name):
	set_train_name(p_train_name)
	var _err = get_train().connect("name_changed", self, "_on_train_name_changed")
	_err = get_train().connect("removing", self, "_on_train_removing")
	_err = get_train().hub.connect("responsiveness_changed", self, "_on_hub_responsiveness_changed")
	_err = LayoutInfo.connect("control_devices_changed", self, "_on_layout_control_devices_changed")
	
	set_controls_disabled(true)
	
	get_node(hub_controls).setup(get_train().hub)

func _on_layout_control_devices_changed(control_devices):
	set_controls_disabled(control_devices or not get_train().hub.responsiveness)

func _on_hub_responsiveness_changed(val):
	set_controls_disabled(LayoutInfo.control_devices or not val)

func set_controls_disabled(mode):
	for child in get_node(control_container).get_children():
		child.disabled=mode

func _on_train_name_changed(_old_name, new_name):
	set_train_name(new_name)

func _on_train_removing(_p_name):
	queue_free()

func set_train_name(p_train_name):
	train_name = p_train_name
	get_node(train_label).text = train_name

func get_train():
	return Devices.trains[train_name]

func _on_start_button_pressed():
	get_train().start()
	
func _on_stop_button_pressed():
	get_train().stop()

func _on_slow_button_pressed():
	get_train().slow()

func _on_change_heading_button_pressed():
	get_train().flip_heading()
