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
	_err = get_train().hub.connect("responsiveness_changed", self, "update_controls_enabled")
	_err = LayoutInfo.connect("control_devices_changed", self, "update_controls_enabled")
	_err = Devices.get_ble_controller().connect("hubs_state_changed", self, "update_controls_enabled")
	
	set_controls_disabled(true)
	
	get_node(hub_controls).setup(get_train().hub)

func update_controls_enabled(_dummy=null):
	set_controls_disabled(LayoutInfo.control_devices or not get_train().hub.responsiveness or Devices.get_ble_controller().is_busy())

func set_controls_disabled(mode):
	for child in get_node(control_container).get_children():
		child.disabled=mode

func _on_train_name_changed(_old_name, new_name):
	set_train_name(new_name)

func _on_train_removing(_p_name):
	Devices.get_ble_controller().disconnect("hubs_state_changed", self, "update_controls_enabled")
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
