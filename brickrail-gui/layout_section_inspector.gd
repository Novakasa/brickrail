extends VBoxContainer

var section = null
var dirtrack = null

func set_section(obj):
	section = obj
	section.connect("unselected", self, "_on_section_unselected")
	section.connect("track_added", self, "_on_section_track_added")
	_on_section_track_added(null)

func _on_section_unselected():
	queue_free()

func _on_section_track_added(track):
	if len(section.tracks) == 1:
		dirtrack = section.tracks[0]
		if dirtrack.track.sensor == null:
			$AddSensor.visible=true
			$SensorPanel.visible=false
		else:
			$AddSensor.visible=false
			$SensorPanel.visible=true
			update_marker_select()
	else:
		$AddSensor.visible=false
		$SensorPanel.visible=false


func _on_CreateBlock_pressed():
	var new_name = "block" + str(len(LayoutInfo.blocks))
	while new_name in LayoutInfo.blocks:
		new_name = new_name + "_"
	$CreateBlockPopup/VBoxContainer/NameEdit.text = new_name
	$CreateBlockPopup.popup_centered()

func _on_AddSensor_pressed():
	$AddSensor.visible=false
	$SensorPanel.visible=true
	update_marker_select()
	var sensor = LayoutSensor.new(LayoutInfo.markers.keys()[0])
	dirtrack.track.add_sensor(sensor)

func _on_BlockOKButton_pressed():
	var block_name = $CreateBlockPopup/VBoxContainer/NameEdit.text
	LayoutInfo.create_block(block_name, section)
	$CreateBlockPopup.hide()


func _on_BlockCancelButton_pressed():
	$CreateBlockPopup.hide()


func _on_CollectSegment_pressed():
	if len(section.tracks)==1:
		section.collect_segment()
	else:
		push_error("can't collect segment on section with more than one track!")

func update_marker_select():
	var marker_select = $SensorPanel/SensorInspector/HBoxContainer/MarkerSelect
	marker_select.clear()
	for markername in LayoutInfo.markers:
		marker_select.add_item(markername)
	if dirtrack.track.sensor != null:
		marker_select.select(LayoutInfo.markers.keys().find(dirtrack.track.sensor.markername))

func get_selected_marker():
	var marker_select = $SensorPanel/SensorInspector/HBoxContainer/MarkerSelect
	return LayoutInfo.markers.keys()[marker_select.selected]

func _on_RemoveSensor_pressed():
	dirtrack.track.remove_sensor()


func _on_MarkerSelect_item_selected(index):
	dirtrack.track.set_sensor_marker(get_selected_marker())


func _on_MarkerAdd_pressed():
	$SensorPanel/MarkerColorAdd.popup_centered()
	var new_name = "marker"+str(len(LayoutInfo.markers))
	while new_name in LayoutInfo.markers:
		new_name = new_name + "_"
	$SensorPanel/MarkerColorAdd/VBoxContainer/HBoxContainer2/LineEdit.text = new_name

func _on_MarkerRemove_pressed():
	LayoutInfo.markers.erase(get_selected_marker())
	update_marker_select()

func _on_MarkerColorAdd_confirmed():
	var color = $SensorPanel/MarkerColorAdd/VBoxContainer/ColorPicker.color
	var markername = $SensorPanel/MarkerColorAdd/VBoxContainer/HBoxContainer2/LineEdit.text
	LayoutInfo.markers[markername] = color
	update_marker_select()
	var index = LayoutInfo.markers.keys().find(markername)
	$SensorPanel/SensorInspector/HBoxContainer/MarkerSelect.select(index)
	_on_MarkerSelect_item_selected(index)
