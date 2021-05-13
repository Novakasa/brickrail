extends Panel

var switch_name
var project
export(NodePath) var switch_label
export(NodePath) var left_button
export(NodePath) var right_button

func setup(p_project, p_switch_name):
	project = p_project
	set_switch_name(p_switch_name)
	get_switch().connect("name_changed", self, "_on_switch_name_changed")
	get_switch().connect("position_changed", self, "_on_switch_position_changed")
	get_switch().connect("controller_changed", self, "_on_switch_controller_changed")
	get_switch().connect("hub_responsiveness_changed", self, "_on_hub_responsiveness_changed")
	$SwitchSettingsDialog.setup(p_project, p_switch_name)
	$SwitchSettingsDialog.show()
	get_node(left_button).disabled=true
	get_node(right_button).disabled=true


func _on_switch_name_changed(p_old_name, p_new_name):
	set_switch_name(p_new_name)

func _on_switch_position_changed(position):
	if position == "left":
		get_node(left_button).disabled=true
		get_node(right_button).disabled=false
	if position == "right":
		get_node(left_button).disabled=false
		get_node(right_button).disabled=true

func _on_hub_responsiveness_changed(val):
	get_node(left_button).disabled= not val
	get_node(right_button).disabled= not val

func set_switch_name(p_switch_name):
	switch_name = p_switch_name
	get_node(switch_label).text = switch_name

func get_switch():
	return project.switches[switch_name]

func _on_settings_button_pressed():
	$SwitchSettingsDialog.show()

func _on_switch_right_button_pressed():
	get_switch().switch("right")
	get_node(right_button).disabled= true

func _on_switch_left_button_pressed():
	get_switch().switch("left")
	get_node(left_button).disabled= true
