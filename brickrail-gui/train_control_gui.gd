extends Panel

var train_name
var project
export(NodePath) var train_label
export(NodePath) var connect_button

func setup(p_project, p_train_name):
	project = p_project
	set_train_name(p_train_name)
	get_train().connect("name_changed", self, "_on_train_name_changed")
	get_train().connect("connected", self, "_on_train_connected")
	get_train().connect("disconnected", self, "_on_train_disconnected")
	get_train().connect("connect_error", self, "_on_train_connect_error")
	$TrainSettingsDialog.setup(p_project, p_train_name)

func _on_train_name_changed(old_name, new_name):
	set_train_name(new_name)

func _on_train_connected():
	var button = get_node(connect_button)
	button.disabled=false
	button.text="disconnect"

func _on_train_disconnected():
	var button = get_node(connect_button)
	button.disabled=false
	button.text="connect"

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
	get_train().run_program()

func _on_connect_button_pressed():
	var button = get_node(connect_button)
	if button.text == "connect":
		get_train().connect_hub()
	if button.text == "disconnect":
		get_train().disconnect_hub()
	button.disabled=true
	
func _on_start_button_pressed():
	get_train().start()
	
func _on_stop_button_pressed():
	get_train().stop()

func _on_settings_button_pressed():
	$TrainSettingsDialog.show()
