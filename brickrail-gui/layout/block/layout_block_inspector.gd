extends VBoxContainer


var block

func set_block(p_block):
	block = p_block
	block.connect("unselected", self, "_on_block_unselected")
	$CanStopCheckBox.pressed = block.can_stop

func _on_block_unselected():
	queue_free()


func _on_AddTrain_pressed():
	var new_name = "train" + str(len(LayoutInfo.trains))
	while new_name in LayoutInfo.trains:
		new_name = new_name + "_"
	$AddTrainDialog.popup_centered()
	$AddTrainDialog/VBoxContainer/GridContainer/TrainNameEdit.text = new_name

func _on_AddTrainDialog_confirmed():
	var trainname = $AddTrainDialog/VBoxContainer/GridContainer/TrainNameEdit.get_text()
	var train: LayoutTrain = LayoutInfo.create_train(trainname)
	train.set_current_block(block)

func _on_AddPriorSensorButton_pressed():
	LayoutInfo.set_input_mode("prior_sensor")


func _on_CanStopCheckBox_toggled(button_pressed):
	block.can_stop = button_pressed
