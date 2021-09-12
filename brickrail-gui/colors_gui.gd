extends VBoxContainer

func _ready():
	Devices.connect("color_added", self, "_on_devices_color_added")
	Devices.connect("color_removed", self, "_on_devices_color_removed")
	Devices.connect("train_added", self, "_on_devices_train_added")

func _on_devices_train_added(trainname):
	var train = Devices.trains[trainname]
	train.connect("color_measured", self, "_on_train_color_measured")

func _on_train_color_measured(color):
	if $ScanCheck.pressed:
		Devices.colors[get_selected_colorname()].add_color(color)

func _on_devices_color_added(colorname):
	var color = Devices.colors[colorname]
	$TabContainer.add_child(color)
	update_color_selector()
	var index = get_colorname_index(colorname)
	$HBoxContainer/ColorSelector.select(index)
	_on_ColorSelector_item_selected(index)

func update_color_selector():
	$HBoxContainer/ColorSelector.clear()
	for colorname in Devices.colors:
		$HBoxContainer/ColorSelector.add_item(colorname)
		var index = $HBoxContainer/ColorSelector.get_item_count()-1
		$HBoxContainer/ColorSelector.set_item_metadata(index, colorname)

func get_colorname_index(colorname):
	for i in range($HBoxContainer/ColorSelector.get_item_count()):
		if $HBoxContainer/ColorSelector.get_item_metadata(i) == colorname:
			return i

func _on_devices_color_removed(colorname):
	update_color_selector()
	if len(Devices.colors)>0:
		var selindex = get_colorname_index(Devices.colors.keys()[0])
		$HBoxContainer/ColorSelector.select(selindex)
		_on_ColorSelector_item_selected(selindex)

func _on_PlusButton_pressed():
	$NewColorDialog.popup_centered()

func _on_NewColorDialog_confirmed():
	var cname = $NewColorDialog/VBoxContainer/HBoxContainer2/NameEdit.text
	var ctypeid = $NewColorDialog/VBoxContainer/HBoxContainer3/TypeSelect.get_selected_id()
	var ctype = ["marker", "speedA", "speedB"][ctypeid]
	Devices.create_color(cname, ctype)

func _on_MinusButton_pressed():
	Devices.colors[get_selected_colorname()].remove()

func get_selected_colorname():
	return $HBoxContainer/ColorSelector.get_selected_metadata()

func _on_ColorSelector_item_selected(index):
	if index>=0:
		$TabContainer.current_tab = index
