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
		$OneWayCheckbox.visible=true
		$OneWayCheckbox.pressed = dirtrack.get_opposite().prohibited
		if dirtrack.get_sensor() == null:
			$AddSensor.visible=true
			$SensorPanel.visible=false
		else:
			$AddSensor.visible=false
			$SensorPanel.visible=true
			update_marker_select()
		if dirtrack.get_next() == null:
			$AddPortal.visible=true
		else:
			$AddPortal.visible=false
	else:
		$AddSensor.visible=false
		$SensorPanel.visible=false
		$OneWayCheckbox.visible=false
		$AddPortal.visible=false


func _on_CreateBlock_pressed():
	if not len(section.tracks)>1:
		push_error("Can't create block on sections with length < 2")
		return
	if section.has_switch():
		push_error("Can't create block on sections with switches")
		return
	if section.has_block():
		push_error("Can't create block on sections with other blocks")
		return
	var new_name = "block" + str(len(LayoutInfo.blocks))
	while new_name in LayoutInfo.blocks:
		new_name = new_name + "_"
	$CreateBlockPopup/VBoxContainer/NameEdit.text = new_name
	$CreateBlockPopup.popup_centered()

func _on_AddSensor_pressed():
	$AddSensor.visible=false
	$SensorPanel.visible=true
	var sensor = LayoutSensor.new(null)
	dirtrack.add_sensor(sensor)
	update_marker_select()

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
	marker_select.add_item("None")
	marker_select.set_item_metadata(0, null)
	var i = 1
	for colorname in Devices.marker_colors:
		marker_select.add_item(colorname)
		marker_select.set_item_metadata(i, colorname)
		i += 1
	var sensor = dirtrack.get_sensor()
	if sensor != null:
		if sensor.marker_color != null:
			marker_select.select(get_colorname_index(sensor.marker_color))

func get_selected_colorname():
	var marker_select = $SensorPanel/SensorInspector/HBoxContainer/MarkerSelect
	return marker_select.get_selected_metadata()

func get_colorname_index(colorname):
	var marker_select = $SensorPanel/SensorInspector/HBoxContainer/MarkerSelect
	for i in range(marker_select.get_item_count()):
		if marker_select.get_item_metadata(i) == colorname:
			return i
	assert(false)
		

func _on_RemoveSensor_pressed():
	dirtrack.remove_sensor()


func _on_MarkerSelect_item_selected(index):
	dirtrack.get_sensor().set_marker_color(get_selected_colorname())


func _on_OneWayCheckbox_toggled(button_pressed):
	section.tracks[0].set_one_way(button_pressed)


func _on_AddPortal_pressed():
	LayoutInfo.set_portal_dirtrack(dirtrack)
	LayoutInfo.set_input_mode("portal")
