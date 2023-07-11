extends VBoxContainer


var block

func _enter_tree():
	var _err = LayoutInfo.connect("layout_mode_changed", Callable(self, "_on_layout_mode_changed"))

func _on_layout_mode_changed(mode):
	var edit_exclusive_nodes = [$AddTrain, $AddPriorSensorButton, $CanStopCheckBox, $CanFlipCheckBox]
	
	for node in edit_exclusive_nodes:
		node.visible = (mode != "control")

func set_block(p_block):
	block = p_block
	$EditableLabel.set_text(LayoutInfo.blocks[block.block_id].get_name())
	$EditableLabel.set_display_text(block.get_name())
	block.connect("unselected", Callable(self, "_on_block_unselected"))
	$CanStopCheckBox.button_pressed = block.can_stop
	$CanFlipCheckBox.button_pressed = block.can_flip
	$RandomTargetCheckBox.button_pressed = block.random_target
	$HBoxContainer/WaitTimeEdit.value = block.wait_time
	_on_layout_mode_changed(LayoutInfo.layout_mode)

func _on_block_unselected():
	queue_free()

func _on_AddTrain_pressed():
	var index = 1
	var new_name = "train" + str(index)
	while new_name in LayoutInfo.trains:
		index += 1
		new_name = "train" + str(index)
	var train: LayoutTrain = LayoutInfo.create_train(new_name)
	train.set_current_block(block)
	
	# $AddTrainDialog.popup_centered()
	# $AddTrainDialog/VBoxContainer/GridContainer/train_idEdit.text = new_name

func _on_AddTrainDialog_confirmed():
	var train_id = $AddTrainDialog/VBoxContainer/GridContainer/train_idEdit.get_text()
	var train: LayoutTrain = LayoutInfo.create_train(train_id)
	train.set_current_block(block)

func _on_AddPriorSensorButton_pressed():
	LayoutInfo.set_layout_mode("prior_sensor")


func _on_CanStopCheckBox_toggled(button_pressed):
	if block.can_stop != button_pressed:
		LayoutInfo.set_layout_changed(true)
	block.can_stop = button_pressed

func _on_CanFlipCheckBox_toggled(button_pressed):
	if block.can_flip != button_pressed:
		LayoutInfo.set_layout_changed(true)
	block.can_flip = button_pressed

func _on_RandomTargetCheckBox_toggled(button_pressed):
	block.set_random_target(button_pressed)

func _on_WaitTimeEdit_value_changed(value):
	block.set_wait_time(value)

func _on_EditableLabel_text_changed(text):
	LayoutInfo.blocks[block.block_id].set_name(text)
	$EditableLabel.set_display_text(block.get_name())
	
