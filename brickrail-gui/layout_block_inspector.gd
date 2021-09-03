extends VBoxContainer


var block

func set_block(p_block):
	block = p_block
	block.connect("unselected", self, "_on_block_unselected")
	
	$TargetOption.clear()
	for id in LayoutInfo.nodes.keys():
		$TargetOption.add_item(id)

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


func _on_ShowRoute0_pressed():
	var target = LayoutInfo.nodes.keys()[$TargetOption.selected]
	var route = block.get_route_to(1, target)
	if route == null:
		push_error("no route to selected target "+target)
	else:
		route.get_full_section().select()


func _on_ShowRoute1_pressed():
	var target = LayoutInfo.nodes.keys()[$TargetOption.selected]
	var route = block.get_route_to(-1, target)
	if route == null:
		push_error("no route to selected target "+target)
	else:
		route.get_full_section().select()
