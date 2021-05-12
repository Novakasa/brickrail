extends Panel

var train_name
var project
export(NodePath) var train_label
export(NodePath) var connect_button
export(NodePath) var run_button

func setup(p_project, p_train_name):
	project = p_project
	set_train_name(p_train_name)
	get_train().connect("name_changed", self, "_on_train_name_changed")
	get_train().connect("connected", self, "_on_train_connected")
	get_train().connect("disconnected", self, "_on_train_disconnected")
	get_train().connect("connect_error", self, "_on_train_connect_error")
	get_train().hub.connect("program_started", self, "_on_program_started")
	get_train().hub.connect("program_stopped", self, "_on_program_stopped")
	$TrainSettingsDialog.setup(p_project, p_train_name)

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

func _on_program_started():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	runbutton.text="stop"
	runbutton.disabled=false
	connectbutton.disabled=true

func _on_program_stopped():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	runbutton.text="run"
	runbutton.disabled=false
	connectbutton.disabled=false

func _on_train_connect_error(data):
	var button = get_node(connect_button)
	button.disabled=false
	button.text="connect"

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

func _on_settings_button_pressed():
	$TrainSettingsDialog.show()
