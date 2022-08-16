extends HSplitContainer

export(NodePath) var input_control_button
export(NodePath) var input_select_button
export(NodePath) var input_draw_button

export(NodePath) var inspector_container
export(NodePath) var layer_container
export(NodePath) var layer_index_edit

func _ready():
	LayoutInfo.connect("input_mode_changed", self, "_on_input_mode_changed")
	LayoutInfo.connect("selected", self, "_on_selected")
	LayoutInfo.connect("layers_changed", self, "_on_layers_changed")
	LayoutInfo.connect("active_layer_changed", self, "_on_active_layer_changed")
	get_node(layer_container).connect("item_selected", self, "_on_layer_container_item_selected")

func _on_layers_changed():
	var layers = get_node(layer_container)
	layers.clear()
	for layer in LayoutInfo.cells:
		layers.add_item("layer "+str(layer))
	
	var edit = get_node(layer_index_edit)
	edit.value = len(LayoutInfo.cells)

func _on_active_layer_changed(l):
	if l==null:
		get_node(layer_container).unselect_all()
		return
	var index = LayoutInfo.cells.keys().find(l)
	get_node(layer_container).select(index)

func _on_layer_container_item_selected(index):
	var l = LayoutInfo.cells.keys()[index]
	LayoutInfo.set_active_layer(l)

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
	Devices.clear()
	LayoutInfo.clear()
	
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
	Devices.clear()
	LayoutInfo.clear()


func _on_CheckBox_toggled(button_pressed):
	LayoutInfo.set_control_devices(button_pressed)


func _on_AutoTarget_toggled(button_pressed):
	LayoutInfo.set_random_targets(button_pressed)


func _on_SpinBox_value_changed(value):
	LayoutInfo.time_scale = value


func _on_add_layer_button_button_down():
	var edit = get_node(layer_index_edit)
	var l = int(edit.value)
	edit.value = l+1
	LayoutInfo.add_layer(l)
