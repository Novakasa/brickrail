extends VBoxContainer


var block

func _enter_tree():
	var _err = LayoutInfo.connect("layout_mode_changed", self, "_on_layout_mode_changed")

func _on_layout_mode_changed(mode):
	var edit_exclusive_nodes = [$AddTrain, $PriorPanel, $PriorLabel, $CanStopCheckBox, $CanFlipCheckBox, $DisableTrainCheckbox]
	
	for node in edit_exclusive_nodes:
		node.visible = (mode != "control")
	
	update_prior_panel()

func set_block(p_block):
	block = p_block
	block.connect("locked_changed", self, "_on_block_locked_changed")
	$EditableLabel.set_text(LayoutInfo.blocks[block.block_id].get_name())
	$EditableLabel.set_display_text(block.get_name())
	block.connect("unselected", self, "_on_block_unselected")
	$CanStopCheckBox.pressed = block.can_stop
	$CanFlipCheckBox.pressed = block.can_flip
	$RandomTargetCheckBox.pressed = block.random_target
	$DisableTrainCheckbox.pressed = block.disable_train
	$HBoxContainer/WaitTimeEdit.value = block.wait_time
	update_prior_panel()
	_on_layout_mode_changed(LayoutInfo.layout_mode)
	$AddTrain.disabled = (block.get_locked() != null)

func update_prior_panel():
	if block.get_prior_sensor_dirtrack() == null:
		if LayoutInfo.layout_mode == "prior_sensor":
			$PriorPanel/AddPriorButton.disabled = true
			$PriorPanel/RemovePriorButton.disabled = true
			$PriorPanel/CancelPriorButton.disabled = false
			return
		$PriorPanel/AddPriorButton.disabled = false
		$PriorPanel/RemovePriorButton.disabled = true
		$PriorPanel/CancelPriorButton.disabled = true
		return
	$PriorPanel/AddPriorButton.disabled = true
	$PriorPanel/RemovePriorButton.disabled = false
	$PriorPanel/CancelPriorButton.disabled = true

func _on_block_unselected():
	queue_free()

func _on_block_locked_changed(trainname):
	# prints("locked changed", trainname)
	$AddTrain.disabled = (trainname != null)

func _on_AddTrain_pressed():
	var train: LayoutTrain = LayoutInfo.create_train()
	train.set_current_block(block)
	
	# $AddTrainDialog.popup_centered()
	# $AddTrainDialog/VBoxContainer/GridContainer/train_idEdit.text = new_name

func _on_AddTrainDialog_confirmed():
	var train: LayoutTrain = LayoutInfo.create_train()
	train.set_current_block(block)

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

func _on_AddPriorSensorButton_pressed():
	LayoutInfo.set_layout_mode("prior_sensor")
	update_prior_panel()

func _on_RemovePriorButton_pressed():
	block.disconnect_prior_sensor_dirtrack()
	update_prior_panel()

func _on_CancelPriorButton_pressed():
	LayoutInfo.set_layout_mode("edit")
	update_prior_panel()

func _on_DisableTrainCheckbox_toggled(button_pressed):
	block.set_disable_train(button_pressed)
	block.get_opposite_block().set_disable_train(button_pressed)
