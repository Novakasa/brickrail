extends VBoxContainer

var section = null

func set_section(obj):
	section = obj
	section.connect("unselected", self, "_on_section_unselected")

func _on_section_unselected():
	queue_free()


func _on_CreateBlock_pressed():
	$CreateBlockPopup/VBoxContainer/NameEdit.text = "block" + str(len(LayoutInfo.blocks))
	$CreateBlockPopup.popup_centered()

func _on_AddMarker_pressed():
	assert(len(section.tracks) == 1)
	section.tracks[0].add_marker()


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
