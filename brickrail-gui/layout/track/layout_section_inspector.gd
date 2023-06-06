extends VBoxContainer

var section = null
var dirtrack = null

func _enter_tree():
	var _err = LayoutInfo.connect("layout_mode_changed", self, "_on_layout_mode_changed")

func _on_layout_mode_changed(mode):
	if mode == "control":
		section.unselect()

func set_section(obj):
	section = obj
	section.connect("unselected", self, "_on_section_unselected")
	section.connect("track_added", self, "_on_section_track_added")
	_on_section_track_added(null)

func _on_section_unselected():
	queue_free()

func _on_section_track_added(_track):
	if len(section.tracks) == 1:
		dirtrack = section.tracks[0]
		$Label.text = dirtrack.id
		$CreateBlock.visible=false
		$OneWayCheckbox.visible=true
		$OneWayCheckbox.pressed = dirtrack.get_opposite().prohibited
		if dirtrack.get_sensor() == null:
			$AddSensor.visible=true
			$SensorPanel.visible=false
		else:
			$AddSensor.visible=false
			$SensorPanel.visible=true
			update_marker_select()
			update_speed_select()
		if dirtrack.get_next() == null:
			$AddPortal.visible=true
		else:
			$AddPortal.visible=false
		$FacingFilterSelector.set_items(["Only forwards", "Only backwards"], [1, -1])
		$FacingFilterSelector.select_meta(section.tracks[0].facing_filter)
	else:
		$Label.text = section.tracks[0].id + "-" + section.tracks[-1].id
		$CreateBlock.visible=true
		$CreateBlock.disabled = false
		$CreateBlock.hint_tooltip = "create block"
		var reason = section.get_block_blocked_reason()
		if reason != null:
			$CreateBlock.disabled = true
			$CreateBlock.hint_tooltip = reason
		$AddSensor.visible=false
		$SensorPanel.visible=false
		$OneWayCheckbox.visible=false
		$AddPortal.visible=false


func _on_CreateBlock_pressed():
	if section.get_block_blocked_reason() != null:
		return
	var index = 1
	var new_name = "block" + str(index)
	while new_name in LayoutInfo.blocks:
		index += 1
		new_name = "block" + str(index)

	$CreateBlockPopup/VBoxContainer/NameEdit.text = new_name
	$CreateBlockPopup.popup_centered()

func _on_AddSensor_pressed():
	$AddSensor.visible=false
	$SensorPanel.visible=true
	var sensor = LayoutSensor.new(null)
	dirtrack.add_sensor(sensor)
	update_marker_select()
	update_speed_select()

func _on_BlockOKButton_pressed():
	var block_name = $CreateBlockPopup/VBoxContainer/NameEdit.text
	LayoutInfo.create_block(block_name, section)
	_on_section_track_added(null)
	$CreateBlockPopup.hide()

func _on_BlockCancelButton_pressed():
	$CreateBlockPopup.hide()

func update_marker_select():
	var marker_select = $SensorPanel/SensorInspector/MarkerSelect
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
	var marker_select = $SensorPanel/SensorInspector/MarkerSelect
	return marker_select.get_selected_metadata()

func get_colorname_index(colorname):
	var marker_select = $SensorPanel/SensorInspector/MarkerSelect
	for i in range(marker_select.get_item_count()):
		if marker_select.get_item_metadata(i) == colorname:
			return i
	assert(false)

func update_speed_select():
	var labels = ["slow", "cruise", "fast"]
	var marker_select = $SensorPanel/SensorInspector/SpeedSelect
	marker_select.set_items(labels, labels)
	marker_select.select_meta(dirtrack.sensor_speed)

func _on_SpeedSelect_meta_selected(meta):
	dirtrack.set_sensor_speed(meta)

func _on_RemoveSensor_pressed():
	dirtrack.remove_sensor()

func _on_MarkerSelect_item_selected(_index):
	dirtrack.get_sensor().set_marker_color(get_selected_colorname())

func _on_OneWayCheckbox_toggled(button_pressed):
	section.tracks[0].set_one_way(button_pressed)

func _on_AddPortal_pressed():
	LayoutInfo.set_portal_dirtrack(dirtrack)
	LayoutInfo.set_layout_mode("portal")

func _on_FacingFilterSelector_meta_selected(meta):
	LayoutInfo.set_layout_changed(true)
	section.tracks[0].facing_filter = meta
