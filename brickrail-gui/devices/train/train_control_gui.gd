extends VBoxContainer

var train_name
export(NodePath) var train_label
export(NodePath) var control_container
export(NodePath) var hub_controls

var markers = ["blue_marker", "red_marker"]
var modes = ["block", "auto", "manual"]
var train: BLETrain

func setup(p_train_name):
	set_train_name(p_train_name)
	var _err = get_train().connect("name_changed", self, "_on_train_name_changed")
	_err = train.connect("removing", self, "_on_train_removing")
	_err = train.hub.connect("responsiveness_changed", self, "update_controls_enabled")
	_err = LayoutInfo.connect("control_devices_changed", self, "update_controls_enabled")
	_err = Devices.get_ble_controller().connect("hubs_state_changed", self, "update_controls_enabled")
	
	set_controls_disabled(true)
	
	get_node(hub_controls).setup(get_train().hub)

func update_controls_enabled(_dummy=null):
	set_controls_disabled(LayoutInfo.control_devices==2 or not get_train().hub.responsiveness or not Devices.get_ble_controller().hub_control_enabled)

func set_controls_disabled(mode):
	for child in get_node(control_container).get_children():
		child.disabled=mode
	if not mode:
		get_node(control_container).get_node("stop_button").pressed=true
		get_node(control_container).get_node("slow_button").pressed=false
		get_node(control_container).get_node("start_button").pressed=false
		get_node(control_container).get_node("fast_button").pressed=false
	
func _on_train_name_changed(_old_name, new_name):
	set_train_name(new_name)

func _on_train_removing(_p_name):
	train.disconnect("removing", self, "_on_train_removing")
	train.hub.disconnect("responsiveness_changed", self, "update_controls_enabled")
	LayoutInfo.disconnect("control_devices_changed", self, "update_controls_enabled")
	Devices.get_ble_controller().disconnect("hubs_state_changed", self, "update_controls_enabled")
	train = null
	queue_free()

func set_train_name(p_train_name):
	train_name = p_train_name
	get_node(train_label).text = train_name
	train = get_train()

func get_train():
	return Devices.trains[train_name]

func _on_start_button_pressed():
	get_node(control_container).get_node("slow_button").pressed=false
	get_node(control_container).get_node("stop_button").pressed=false
	get_node(control_container).get_node("fast_button").pressed=false
	get_train().start()
	
func _on_stop_button_pressed():
	get_node(control_container).get_node("slow_button").pressed=false
	get_node(control_container).get_node("start_button").pressed=false
	get_node(control_container).get_node("fast_button").pressed=false
	get_train().stop()

func _on_slow_button_pressed():
	get_node(control_container).get_node("stop_button").pressed=false
	get_node(control_container).get_node("start_button").pressed=false
	get_node(control_container).get_node("fast_button").pressed=false
	get_train().slow()

func _on_change_heading_button_pressed():
	get_train().flip_heading()

func _on_fast_button_pressed():
	get_node(control_container).get_node("slow_button").pressed=false
	get_node(control_container).get_node("start_button").pressed=false
	get_node(control_container).get_node("stop_button").pressed=false
	get_train().fast()

func _on_RemoveButton_pressed():
	yield(train.safe_remove_coroutine(), "completed")
