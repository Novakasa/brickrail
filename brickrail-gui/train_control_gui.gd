extends Panel

var train_name
var project
export(NodePath) var train_label

func setup(p_project, p_train_name):
	project = p_project
	set_train_name(p_train_name)
	get_train().connect("name_changed", self, "_on_train_name_changed")
	$TrainSettingsDialog.setup(p_project, p_train_name)

func _on_train_name_changed(old_name, new_name):
	set_train_name(new_name)

func set_train_name(p_train_name):
	train_name = p_train_name
	get_node(train_label).text = train_name

func get_train():
	return project.trains[train_name]

func _on_run_button_pressed():
	get_train().run_program()

func _on_connect_button_pressed():
	get_train().connect_hub()
	
func _on_start_button_pressed():
	get_train().start()
	
func _on_stop_button_pressed():
	get_train().stop()

func _on_settings_button_pressed():
	$TrainSettingsDialog.show()
