extends Panel

var train_name
var project
export(NodePath) var train_label
export(NodePath) var connect_button
export(NodePath) var run_button
export(NodePath) var control_container
export(NodePath) var auto_container

var markers = ["blue_marker", "red_marker"]
var modes = ["block", "auto", "manual"]

func setup(p_project, p_train_name):
	project = p_project
	set_train_name(p_train_name)
	get_train().connect("name_changed", self, "_on_train_name_changed")
	get_train().connect("connected", self, "_on_train_connected")
	get_train().connect("disconnected", self, "_on_train_disconnected")
	get_train().connect("connect_error", self, "_on_train_connect_error")
	get_train().hub.connect("program_started", self, "_on_program_started")
	get_train().hub.connect("program_stopped", self, "_on_program_stopped")
	get_train().connect("mode_changed", self, "_on_mode_changed")
	get_train().connect("slow_marker_changed", self, "_on_slow_marker_changed")
	get_train().connect("stop_marker_changed", self, "_on_stop_marker_changed")
	
	var auto_container_node = get_node(auto_container)
	
	var mode_select = auto_container_node.get_node("mode_select")
	for mode in modes:
		mode_select.add_item(mode)
	mode_select.select(0)
	
	var slow_marker_select = auto_container_node.get_node("slow_marker_select")
	for marker in markers:
		slow_marker_select.add_item(marker)
	slow_marker_select.select(0)
	
	var stop_marker_select = auto_container_node.get_node("stop_marker_select")
	for marker in markers:
		stop_marker_select.add_item(marker)
	stop_marker_select.select(0)
	
	set_controls_disabled(true)
	
	$TrainSettingsDialog.setup(p_project, p_train_name)

func set_controls_disabled(mode):
	for child in get_node(control_container).get_children():
		child.disabled=mode
	var auto_container_node = get_node(auto_container)
	auto_container_node.get_node("mode_select").disabled=mode
	auto_container_node.get_node("slow_marker_select").disabled=mode
	auto_container_node.get_node("stop_marker_select").disabled=mode

func _on_train_name_changed(old_name, new_name):
	set_train_name(new_name)

func _on_train_connected():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	connectbutton.disabled=false
	runbutton.disabled=false
	connectbutton.text="disconnect"

func _on_train_disconnected():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	connectbutton.disabled=false
	connectbutton.text="connect"
	runbutton.disabled=true
	set_controls_disabled(true)

func _on_program_started():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	runbutton.text="stop"
	runbutton.disabled=false
	connectbutton.disabled=true
	set_controls_disabled(false)

func _on_program_stopped():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	runbutton.text="run"
	runbutton.disabled=false
	connectbutton.disabled=false
	set_controls_disabled(false)

func _on_train_connect_error(data):
	var button = get_node(connect_button)
	button.disabled=false
	button.text="connect"

func _on_mode_changed(marker):
	get_node(auto_container).get_node("mode_select").disabled=false
	get_node(auto_container).get_node("mode_select").select(markers.find(marker))

func _on_slow_marker_changed(marker):
	get_node(auto_container).get_node("slow_marker_select").disabled=false
	get_node(auto_container).get_node("slow_marker_select").select(markers.find(marker))

func _on_stop_marker_changed(marker):
	get_node(auto_container).get_node("stop_marker_select").disabled=false
	get_node(auto_container).get_node("stop_marker_select").select(markers.find(marker))

func set_train_name(p_train_name):
	train_name = p_train_name
	get_node(train_label).text = train_name

func get_train():
	return project.trains[train_name]

func _on_run_button_pressed():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	if runbutton.text == "run":
		get_train().hub.run_program()
	if runbutton.text == "stop":
		get_train().hub.stop_program()
		set_controls_disabled(true)
	runbutton.disabled=true
	connectbutton.disabled=true

func _on_connect_button_pressed():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	if connectbutton.text == "connect":
		get_train().connect_hub()
	if connectbutton.text == "disconnect":
		get_train().disconnect_hub()
	connectbutton.disabled=true
	runbutton.disabled=true
	
func _on_start_button_pressed():
	get_train().start()
	
func _on_stop_button_pressed():
	get_train().stop()

func _on_slow_button_pressed():
	get_train().slow()

func _on_settings_button_pressed():
	$TrainSettingsDialog.show()


func _on_mode_select_item_selected(index):
	get_train().set_mode(modes[index])
	get_node(auto_container).get_node("mode_select").disabled=true

func _on_slow_marker_select_item_selected(index):
	get_train().set_slow_marker(markers[index])
	get_node(auto_container).get_node("slow_marker_select").disabled=true

func _on_stop_marker_select_item_selected(index):
	get_train().set_stop_marker(markers[index])
	get_node(auto_container).get_node("stop_marker_select").disabled=true
