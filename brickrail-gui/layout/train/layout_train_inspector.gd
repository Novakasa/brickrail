extends VBoxContainer

var train = null

func set_train(obj):
	train = obj
	train.connect("unselected", self, "_on_train_unselected")
	train.connect("ble_train_changed", self, "_on_train_ble_train_changed")
	$FixedFacingCheckbox.pressed = train.fixed_facing
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

func _on_FlipHeading_pressed():
	train.virtual_train.flip_heading()

func _on_FlipFacing_pressed():
	train.flip_facing()

func _on_Start_pressed():
	train.start()

func _on_Stop_pressed():
	train.virtual_train.stop()

func _on_Slow_pressed():
	train.virtual_train.slow()

func _on_FixedFacingCheckbox_toggled(button_pressed):
	train.fixed_facing = button_pressed

func _on_BLETrainSelector_meta_selected(meta):
	train.set_ble_train(meta)
