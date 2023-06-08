extends VBoxContainer

var train = null

func _enter_tree():
	var _err = LayoutInfo.connect("layout_mode_changed", self, "_on_layout_mode_changed")

func _on_layout_mode_changed(mode):
	var edit_exclusive_nodes = [$BLETrainContainer, $ColorLabel, $WagonLabel, $WagonEdit, $ColorButton]
	
	for node in edit_exclusive_nodes:
		node.visible = (mode != "control")

func set_train(obj):
	train = obj
	$Label.text = train.trainname
	train.connect("unselected", self, "_on_train_unselected")
	train.connect("ble_train_changed", self, "_on_train_ble_train_changed")
	$SensorAdvanceCheckbox.pressed = not train.virtual_train.allow_sensor_advance
	$ColorButton.color = train.virtual_train.color
	$WagonEdit.value = len(train.virtual_train.wagons)
	var _err = Devices.connect("trains_changed", self, "_on_devices_trains_changed")
	update_ble_train_selector()
	select_ble_train(train.ble_train)
	_on_layout_mode_changed(LayoutInfo.layout_mode)
	
	$ReversingBehaviorSelector.set_items(
		["Disabled", "Discouraged", "Allowed"],
		["off", "penalty", "on"])
	$ReversingBehaviorSelector.select_meta(train.reversing_behavior)
	
	$RandomTargetsCheckBox.pressed = train.random_targets
	
	update_storage_controls()

func update_storage_controls():
	for child in $Storage.get_children():
		$Storage.remove_child(child)
		child.queue_free()
	if train.ble_train == null:
		return
	var labels = train.ble_train.storage_labels
	var max_limits = train.ble_train.max_limits
	var order = [6,1,2,3,4,5,0]
	for i in order:
		var label = Label.new()
		label.text = labels[i]
		$Storage.add_child(label)
		if max_limits[i] == -1:
			var checkbox = CheckBox.new()
			var _err = checkbox.connect("toggled", self, "_on_storage_val_edited", [i, "bool"])
			checkbox.pressed = train.ble_train.hub.storage[i] == 1
			$Storage.add_child(checkbox)
		else:
			var edit = SpinBox.new()
			var _err = edit.connect("value_changed", self, "_on_storage_val_edited", [i, "int"])
			edit.max_value = max_limits[i]
			edit.value = train.ble_train.hub.storage[i]
			$Storage.add_child(edit)

func _on_storage_val_edited(value, index, type):
	if type == "int":
		train.ble_train.hub.store_value(index, int(value))
	if type == "bool":
		train.ble_train.hub.store_value(index, int(value))
	LayoutInfo.set_layout_changed(true)

func select_ble_train(ble_train):
	if ble_train == null:
		$BLETrainContainer/BLETrainSelector.select_meta(null)
	else:
		$BLETrainContainer/BLETrainSelector.select_meta(ble_train.name)
	update_storage_controls()

func _on_train_ble_train_changed():
	select_ble_train(train.ble_train)

func _on_devices_trains_changed():
	update_ble_train_selector()

func update_ble_train_selector():
	$BLETrainContainer/BLETrainSelector.set_items(Devices.trains.keys(), Devices.trains.keys())

func _on_train_unselected():
	queue_free()

func _on_BLETrainSelector_meta_selected(meta):
	train.set_ble_train(meta)

func _on_SensorAdvanceCheckbox_toggled(button_pressed):
	train.virtual_train.allow_sensor_advance = not button_pressed

func _on_ColorButton_color_changed(color):
	train.virtual_train.set_color(color)

func _on_WagonEdit_value_changed(value):
	train.virtual_train.set_num_wagons(int(value))

func _on_SetHomeButton_pressed():
	train.set_as_home()

func _on_GoHomeButton_pressed():
	if LayoutInfo.layout_mode == "control":
		train.go_home()
	else:
		train.reset_to_home_position()

func _on_ReversingBehaviorSelector_meta_selected(meta):
	train.set_reversing_behavior(meta)

func _on_RandomTargetsCheckBox_toggled(button_pressed):
	train.set_random_targets(button_pressed)
