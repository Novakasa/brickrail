extends Panel

var switch_name
export(NodePath) var switch_label
export(NodePath) var left_button
export(NodePath) var right_button

func setup(p_switch_name):
	set_switch_name(p_switch_name)
	get_switch().connect("name_changed", self, "_on_switch_name_changed")
	get_switch().connect("position_changed", self, "_on_switch_position_changed")
	get_switch().connect("responsiveness_changed", self, "_on_switch_responsiveness_changed")
	$SwitchSettingsDialog.setup(p_switch_name)
	$SwitchSettingsDialog.show()
	get_node(left_button).disabled=true
	get_node(right_button).disabled=true


func _on_switch_name_changed(p_old_name, p_new_name):
	set_switch_name(p_new_name)

func _on_switch_position_changed(position):
	prints("[switch_gui] switch position cahnged:", position)
	if position == "left":
		get_node(left_button).disabled=true
		get_node(right_button).disabled=false
	if position == "right":
		get_node(left_button).disabled=false
		get_node(right_button).disabled=true
	if position == "unknown":
		get_node(left_button).disabled=false
		get_node(right_button).disabled=false

func _on_switch_responsiveness_changed(val):
	prints("[switch_gui] switch responsiveness cahnged:", val)
	if not val:
		get_node(left_button).disabled= true
		get_node(right_button).disabled= true

func set_switch_name(p_switch_name):
	switch_name = p_switch_name
	get_node(switch_label).text = switch_name
	get_node(switch_label).switch = get_switch()

func get_switch():
	return Devices.switches[switch_name]

func _on_settings_button_pressed():
	$SwitchSettingsDialog.show()

func _on_switch_right_button_pressed():
	get_switch().switch("right")

func _on_switch_left_button_pressed():
	get_switch().switch("left")
