extends VBoxContainer

var train = null

func set_train(obj):
	train = obj
	train.connect("unselected", self, "_on_train_unselected")
	train.connect("ble_train_changed", self, "_on_train_ble_train_changed")
	$FixedFacingCheckbox.pressed = train.fixed_facing
	$SensorAdvanceCheckbox.pressed = not train.virtual_train.allow_sensor_advance
	$ColorButton.color = train.virtual_train.color
	$WagonEdit.value = len(train.virtual_train.wagons)
	Devices.connect("trains_changed", self, "_on_devices_trains_changed")
	update_ble_train_selector()
	select_ble_train(train.ble_train)

func select_ble_train(ble_train):
	if ble_train == null:
		$BLETrainContainer/BLETrainSelector.select_meta(null)
	else:
		$BLETrainContainer/BLETrainSelector.select_meta(ble_train.name)

func _on_train_ble_train_changed():
	select_ble_train(train.ble_train)

func _on_devices_trains_changed():
	update_ble_train_selector()

func update_ble_train_selector():
	$BLETrainContainer/BLETrainSelector.set_items(Devices.trains.keys(), Devices.trains.keys())

func _on_train_unselected():
	queue_free()

func _on_FixedFacingCheckbox_toggled(button_pressed):
	train.fixed_facing = button_pressed

func _on_BLETrainSelector_meta_selected(meta):
	train.set_ble_train(meta)

func _on_SensorAdvanceCheckbox_toggled(button_pressed):
	train.virtual_train.allow_sensor_advance = not button_pressed

func _on_ColorButton_color_changed(color):
	train.virtual_train.set_color(color)

func _on_WagonEdit_value_changed(value):
	train.virtual_train.set_num_wagons(int(value))
