extends HSplitContainer

@export var inspector_container: NodePath
@export var layer_container: NodePath
@export var layer_index_edit: NodePath
@export var edit_tab_path: NodePath
@export var control_tab_path: NodePath

var edit_tab
var control_tab

func _ready():
	var _err = LayoutInfo.connect("layout_mode_changed", Callable(self, "_on_layout_mode_changed"))
	_err = LayoutInfo.connect("selected", Callable(self, "_on_selected"))
	_err = LayoutInfo.connect("layers_changed", Callable(self, "_on_layers_changed"))
	_err = LayoutInfo.connect("active_layer_changed", Callable(self, "_on_active_layer_changed"))
	_err = LayoutInfo.connect("trains_running", Callable(self, "_on_layout_trains_running"))
	_err = LayoutInfo.connect("random_targets_set", Callable(self, "_on_layout_random_targets_set"))
	_err = LayoutInfo.connect("control_devices_changed", Callable(self, "_on_layout_control_devices_changed"))
	
	_err = Devices.get_ble_controller().connect("hubs_state_changed", Callable(self, "_on_hubs_state_changed"))
	_err = get_node(layer_container).connect("item_selected", Callable(self, "_on_layer_container_item_selected"))
	_on_layers_changed()
	_on_layout_mode_changed(LayoutInfo.layout_mode)
	$SaveLayoutDialog.current_path = Settings.layout_path
	$OpenLayoutDialog.current_path = Settings.layout_path
	$SaveConfirm.set_label("Unsaved changes! Save?")
	$SaveConfirm.add_action_button("cancel", "Cancel")
	$SaveConfirm.add_action_button("no save", "Discard")
	$SaveConfirm.add_action_button("save", "Save")
	$SaveConfirm.add_action_button("save as", "Save as...")
	
	edit_tab = get_node(edit_tab_path)
	control_tab = get_node(control_tab_path)
	
	get_window().set_title("Brickrail - New layout")

func _on_hubs_state_changed():
	var new_layout_disabled = not Devices.get_ble_controller().hub_control_enabled
	# edit_tab.get_node("LayoutNew").disabled = new_layout_disabled
	# edit_tab.get_node("LayoutOpen").disabled = new_layout_disabled
	control_tab.get_node("ControlDevicesSelector").disabled = new_layout_disabled

func _on_layout_random_targets_set(set):
	control_tab.get_node("AutoTarget").button_pressed = set

func _on_layout_trains_running(running):
	if running:
		$LayoutSplit/LayoutModeTabs.set_tab_disabled(0, true)
		control_tab.get_node("ControlDevicesSelector").disabled = true
	else:
		$LayoutSplit/LayoutModeTabs.set_tab_disabled(0, false)
		control_tab.get_node("ControlDevicesSelector").disabled = false

func _on_layers_changed():
	var layers = get_node(layer_container)
	layers.clear()
	var remove_button = $VSplitContainer/VBoxContainer/HBoxContainer/remove_layer_button
	remove_button.disabled=true
	if len(LayoutInfo.cells)>1:
		remove_button.disabled=false
	for layer in LayoutInfo.cells:
		layers.add_item("layer "+str(layer))
	# var edit = get_node(layer_index_edit)
	# edit.value = len(LayoutInfo.cells)

func _on_active_layer_changed(l):
	if l==null:
		get_node(layer_container).deselect_all()
		return
	var index = LayoutInfo.cells.keys().find(l)
	get_node(layer_container).select(index)

func _on_layer_container_item_selected(index):
	var l = LayoutInfo.cells.keys()[index]
	LayoutInfo.set_active_layer(l)

func _on_layout_mode_changed(mode):
	var index = ["edit", "control"].find(mode)
	var disabled = mode == "control"
	$VSplitContainer/VBoxContainer/HBoxContainer/remove_layer_button.disabled = disabled or len(LayoutInfo.cells)<=1
	$VSplitContainer/VBoxContainer/HBoxContainer/add_layer_button.disabled = disabled
	if index < 0:
		return
	$LayoutSplit/LayoutModeTabs.current_tab = index

func _on_selected(obj):
	get_node(inspector_container).add_child(obj.get_inspector())

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Logger.info("[LayoutGUI] manual quit requested!")
		await get_tree().idle_frame
		var saved = await check_save_changes_coroutine()
		if saved == "canceled":
			return
		await Devices.get_ble_controller().clean_exit_coroutine()
		LayoutInfo.store_train_positions()
		Settings.save_configfile()
		get_tree().quit()

func check_save_changes_coroutine():
	if not LayoutInfo.layout_changed:
		await get_tree().idle_frame
		return
	$SaveConfirm.popup_centered()
	var action = await $SaveConfirm.get_user_action_coroutine()
	if action == "save" and LayoutInfo.layout_file == null:
		action = "save as"
	if action == "save as":
		var result = await $SaveLayoutDialog.get_file_action_coroutine().completed
		if result[0] == "file_selected":
			save_layout(result[1])
			return "saved"
		return "canceled"
	if action == "save":
		save_layout(LayoutInfo.layout_file)
		return "saved"
	if action == "cancel":
		return "canceled"
	return "not saved"

func _on_LayoutSave_pressed():
	var result = await $SaveLayoutDialog.get_file_action_coroutine().completed
	if result[0] == "file_selected":
		save_layout(result[1])

func save_layout(path):
	var struct = {}
	struct["devices"] = Devices.serialize()
	struct["layout"] = LayoutInfo.serialize()
	var serial = JSON.stringify(struct, "\t")
	if FileAccess.file_exists(path):
		var parent = DirAccess.open(path)
		parent.remove(path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(serial)
	file.close()
	LayoutInfo.layout_file = path
	Settings.layout_path = path
	$SaveLayoutDialog.current_path = path
	$OpenLayoutDialog.current_path = path
	LayoutInfo.set_layout_changed(false)
	get_window().set_title("Brickrail - "+path)

func _on_LayoutOpen_pressed():
	var saved = await check_save_changes_coroutine()
	if saved == "canceled":
		return
	var result = await $OpenLayoutDialog.get_file_action_coroutine().completed
	if result[0] == "file_selected":
		open_layout(result[1])

func open_layout(path):
	LayoutInfo.store_train_positions()
	await Devices.clear_coroutine()
	LayoutInfo.clear()
	
	var file = FileAccess.open(path, 1)
	var serial = file.get_as_text()
	var test_json_conv = JSON.new()
	var _err = test_json_conv.parse(serial)
	var struct = test_json_conv.data
	if not "layout" in struct:
		LayoutInfo.load(struct)
		return
	if "devices" in struct:
		Devices.load(struct.devices)
	LayoutInfo.load(struct.layout)
	LayoutInfo.layout_file = path
	Settings.layout_path = path
	$SaveLayoutDialog.current_path = path
	$OpenLayoutDialog.current_path = path
	LayoutInfo.set_layout_changed(false)
	get_window().set_title("Brickrail - "+path)
	LayoutInfo.restore_train_positions()


func _on_LayoutNew_pressed():
	var saved = await check_save_changes_coroutine()
	if saved == "canceled":
		return
	LayoutInfo.store_train_positions()
	await Devices.clear_coroutine()
	LayoutInfo.clear()
	LayoutInfo.layout_file = null
	LayoutInfo.set_layout_changed(false)
	get_window().set_title("Brickrail - New layout")


func _on_ControlDevicesSelector_item_selected(index):
	Logger.info("[LayoutGUI] control devices selector changed: %s" % index)
	if index==0:
		LayoutInfo.set_control_devices(LayoutInfo.CONTROL_OFF)
		return

	if Devices.get_ble_controller().are_hubs_ready():
		# TODO cleanup ble device state (stop everything?)
		LayoutInfo.set_control_devices(index)
	else:
		LayoutInfo.control_enabled = false
		LayoutInfo.set_random_targets(false)
		control_tab.get_node("ControlDevicesSelector").disabled = true
		control_tab.get_node("AutoTarget").disabled = true
		
		var result = await Devices.get_ble_controller().connect_and_run_all_coroutine()
		if Devices.get_ble_controller().are_hubs_ready() and result=="success":
			LayoutInfo.set_control_devices(index)
		else:
			control_tab.get_node("ControlDevicesSelector").select(0)
			LayoutInfo.set_control_devices(0)
		control_tab.get_node("ControlDevicesSelector").disabled = false
		LayoutInfo.control_enabled = true
		control_tab.get_node("AutoTarget").disabled = false

func _on_layout_control_devices_changed(control_devices):
	control_tab.get_node("ControlDevicesSelector").select(control_devices)
	control_tab.get_node("EmergencyStopButton").disabled = not control_devices

func _on_AutoTarget_toggled(button_pressed):
	Logger.info("[LayoutGUI] random targets toggled: %s" % button_pressed)
	LayoutInfo.set_random_targets(button_pressed)


func _on_SpinBox_value_changed(value):
	LayoutInfo.time_scale = value


func _on_add_layer_button_pressed():
	var l = 0
	while l in LayoutInfo.cells:
		l += 1
	LayoutInfo.add_layer(l)


func _on_StopAllButton_pressed():
	Logger.info("[LayoutGUI] Stop route button pressed")
	LayoutInfo.stop_all_trains()

func _on_LayoutModeTabs_tab_changed(tab):
	var mode = ["edit", "control"][tab]
	LayoutInfo.set_layout_mode(mode)

func _on_EmergencyStopButton_pressed():
	Logger.info("[LayoutGUI] Emergency stop button pressed")
	LayoutInfo.emergency_stop()

func _on_remove_layer_button_pressed():
	var idx = LayoutInfo.cells.keys().find(LayoutInfo.active_layer)
	LayoutInfo.remove_layer(LayoutInfo.active_layer)
	var new_active = LayoutInfo.cells.keys()[idx-1]
	if idx == 0:
		new_active = LayoutInfo.cells.keys()[idx]
	LayoutInfo.set_active_layer(new_active)

func _on_LayerUnfoldCheckbox_toggled(button_pressed):
	LayoutInfo.set_layers_unfolded(button_pressed)

