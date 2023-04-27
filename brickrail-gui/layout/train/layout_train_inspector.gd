extends VBoxContainer

var train = null

func _enter_tree():
	var _err = LayoutInfo.connect("layout_mode_changed", self, "_on_layout_mode_changed")

func _on_layout_mode_changed(mode):
	var edit_exclusive_nodes = [$BLETrainContainer, $ColorLabel, $WagonLabel, $WagonEdit, $ColorButton, $InvertMotorCheckbox]
	
	for node in edit_exclusive_nodes:
		node.visible = (mode != "control")

func set_train(obj):
	train = obj
	train.connect("unselected", self, "_on_train_unselected")
	train.connect("ble_train_changed", self, "_on_train_ble_train_changed")
	$FixedFacingCheckbox.pressed = train.fixed_facing
	$SensorAdvanceCheckbox.pressed = not train.virtual_train.allow_sensor_advance
	$ColorButton.color = train.virtual_train.color
	$WagonEdit.value = len(train.virtual_train.wagons)
	var _err = Devices.connect("trains_changed", self, "_on_devices_trains_changed")
	update_ble_train_selector()
	select_ble_train(train.ble_train)
	if train.ble_train == null:
		$InvertMotorCheckbox.disabled=true
	else:
		$InvertMotorCheckbox.disabled=false
	_on_layout_mode_changed(LayoutInfo.layout_mode)
	
	update_storage_controls()

func update_storage_controls():
	for child in $Storage.get_children():
		$Storage.remove_child(child)
		child.queue_free()
	if train.ble_train == null:
		return
	var labels = train.ble_train.storage_labels
	var max_limits = train.ble_train.max_limits
	for i in range(len(labels)):
		var label = Label.new()
		label.text = labels[i]
		var edit = SpinBox.new()
		var _err = edit.connect("value_changed", self, "_on_storage_val_edited", [i])
		edit.max_value = max_limits[i]
		edit.value = train.ble_train.hub.storage[i]
		$Storage.add_child(label)
		$Storage.add_child(edit)

func _on_storage_val_edited(value, index):
	train.ble_train.hub.store_value(index, value)

func select_ble_train(ble_train):
	if ble_train == null:
		$BLETrainContainer/BLETrainSelector.select_meta(null)
		$InvertMotorCheckbox.disabled=true
	else:
		$BLETrainContainer/BLETrainSelector.select_meta(ble_train.name)
		$InvertMotorCheckbox.disabled=false
		$InvertMotorCheckbox.pressed = ble_train.motor_inverted
	update_storage_controls()

func _on_train_ble_train_changed():
	select_ble_train(train.ble_train)

func _on_devices_trains_changed():
	update_ble_train_selector()

func update_ble_train_selector():
	$BLETrainContainer/BLETrainSelector.set_items(Devices.trains.keys(), Devices.trains.keys())

func _on_train_unselected():
	queue_free()

func _on_FixedFacingCheckbox_toggled(button_pressed):
	train.set_fixed_facing(button_pressed)

func _on_BLETrainSelector_meta_selected(meta):
	train.set_ble_train(meta)

func _on_SensorAdvanceCheckbox_toggled(button_pressed):
	train.virtual_train.allow_sensor_advance = not button_pressed

func _on_ColorButton_color_changed(color):
	train.virtual_train.set_color(color)

func _on_WagonEdit_value_changed(value):
	train.virtual_train.set_num_wagons(int(value))

func _on_InvertMotorCheckbox_toggled(button_pressed):
	LayoutInfo.set_layout_changed(true)
	train.ble_train.set_motor_inverted(button_pressed)
