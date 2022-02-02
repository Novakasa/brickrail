extends HSplitContainer

export(NodePath) var input_control_button
export(NodePath) var input_select_button
export(NodePath) var input_draw_button

export(NodePath) var inspector_container

func _ready():
	LayoutInfo.connect("input_mode_changed", self, "_on_input_mode_changed")
	LayoutInfo.connect("selected", self, "_on_selected")

func _on_input_mode_changed(mode):
	var buttons = {
		"control": get_node(input_control_button),
		"select": get_node(input_select_button),
		"draw": get_node(input_draw_button)
		}
	for key in buttons:
		if key == mode:
			buttons[key].pressed=true
		else:
			buttons[key].pressed=false

func _on_LayoutControl_pressed():
	LayoutInfo.set_input_mode("control")


func _on_LayoutSelect_pressed():
	LayoutInfo.set_input_mode("select")


func _on_LayoutDraw_pressed():
	LayoutInfo.set_input_mode("draw")

func _on_selected(obj):
	get_node(inspector_container).add_child(obj.get_inspector())


func _on_LayoutSave_pressed():
	
	$SaveLayoutDialog.popup()


func _on_SaveLayoutDialog_file_selected(path):
	var struct = {}
	struct["devices"] = Devices.serialize()
	struct["layout"] = LayoutInfo.serialize()
	var serial = JSON.print(struct, "\t")
	var dir = Directory.new()
	if dir.file_exists(path):
		dir.remove(path)
	var file = File.new()
	file.open(path, 2)
	file.store_string(serial)
	file.close()


func _on_LayoutOpen_pressed():
	$OpenLayoutDialog.popup()


func _on_OpenLayoutDialog_file_selected(path):
	var file = File.new()
	file.open(path, 1)
	var serial = file.get_as_text()
	var struct = JSON.parse(serial).result
	if not "layout" in struct:
		LayoutInfo.load(struct)
		return
	if "devices" in struct:
		Devices.load(struct.devices)
	LayoutInfo.load(struct.layout)


func _on_LayoutNew_pressed():
	LayoutInfo.clear()


func _on_CheckBox_toggled(button_pressed):
	LayoutInfo.set_control_devices(button_pressed)


func _on_AutoTarget_toggled(button_pressed):
	LayoutInfo.set_random_targets(button_pressed)


func _on_SpinBox_value_changed(value):
	LayoutInfo.time_scale = value
