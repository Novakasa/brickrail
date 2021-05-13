extends Panel

var controller_name
var project
export(NodePath) var controller_label
export(NodePath) var hub_controls

signal train_action(train, action)

func setup(p_project, p_controller_name):
	project = p_project
	set_controller_name(p_controller_name)
	get_controller().connect("name_changed", self, "_on_controller_name_changed")
	get_node(hub_controls).setup(get_controller().hub)
	$LayoutControllerSettingsDialog.setup(p_project, p_controller_name)
	# $LayoutControllerSettingsDialog.show()

func _on_controller_name_changed(p_old_name, p_new_name):
	set_controller_name(p_new_name)

func set_controller_name(p_controller_name):
	controller_name = p_controller_name
	get_node(controller_label).text = controller_name

func get_controller():
	return project.layout_controllers[controller_name]

func _on_settings_button_pressed():
	$LayoutControllerSettingsDialog.show()
