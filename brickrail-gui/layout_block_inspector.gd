extends VBoxContainer


var block

func set_block(p_block):
	block = p_block
	block.connect("unselected", self, "_on_block_unselected")

func _on_block_unselected():
	queue_free()


func _on_AddTrain_pressed():
	$AddTrainDialog.popup_centered()
	$AddTrainDialog/VBoxContainer/GridContainer/TrainNameEdit.text = "train"+str(len(LayoutInfo.trains))


func _on_AddTrainDialog_confirmed():
	var trainname = $AddTrainDialog/VBoxContainer/GridContainer/TrainNameEdit.get_text()
	var train: LayoutTrain = LayoutInfo.create_train(trainname)
	train.set_current_block(block.logical_blocks[0])


func _on_ShowRoute0_pressed():
	var target = $TargetEdit.text
	var route = block.logical_blocks[0].get_route_to(target)
	if route == null:
		push_error("no route to selected target "+target)
	else:
		route.get_full_section().select()


func _on_ShowRoute1_pressed():
	var target = $TargetEdit.text
	var route = block.logical_blocks[1].get_route_to(target)
	if route == null:
		push_error("no route to selected target "+target)
	else:
		route.get_full_section().select()
