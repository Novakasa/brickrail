extends Panel

var switch
export(NodePath) var device1_option
export(NodePath) var device2_option

var SwitchInspectorMotorSettings = preload("res://layout/switch/switch_inspector_motor_settings.tscn")

func set_switch(p_switch):
	switch = p_switch
	switch.connect("unselected", self, "_on_switch_unselected")
	
	var inspector1 = SwitchInspectorMotorSettings.instance()
	$VBoxContainer.add_child(inspector1)
	inspector1.connect("motor_selected", self, "_on_motor1_selected")
	inspector1.setup(switch.motor1)
	if len(switch.switch_positions) > 2:
		var inspector2 = SwitchInspectorMotorSettings.instance()
		$VBoxContainer.add_child(inspector2)
		inspector2.connect("motor_selected", self, "_on_motor2_selected")
		inspector2.setup(switch.motor2)

func _on_motor1_selected(motor):
	switch.set_motor1(motor)

func _on_motor2_selected(motor):
	switch.set_motor2(motor)

func _on_switch_unselected():
	queue_free()
