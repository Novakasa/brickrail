extends Panel

var switch
var inspector1
var inspector2

var SwitchInspectorMotorSettings = preload("res://layout/switch/switch_inspector_motor_settings.tscn")

func _enter_tree():
	LayoutInfo.connect("layout_mode_changed", self, "_on_layout_mode_changed")

func _on_layout_mode_changed(mode):
	var edit_exclusive_nodes = [inspector1]
	
	for node in edit_exclusive_nodes:
		node.visible = (mode != "control")
		
func set_switch(p_switch):
	switch = p_switch
	switch.connect("unselected", self, "_on_switch_unselected")
	switch.connect("motors_changed", self, "_on_switch_motors_changed")
	
	inspector1 = SwitchInspectorMotorSettings.instance()
	$VBoxContainer.add_child(inspector1)
	inspector1.connect("motor_selected", self, "_on_motor1_selected")
	inspector1.setup(switch.motor1)
	if len(switch.switch_positions) > 2:
		inspector2 = SwitchInspectorMotorSettings.instance()
		$VBoxContainer.add_child(inspector2)
		inspector2.connect("motor_selected", self, "_on_motor2_selected")
		inspector2.setup(switch.motor2)
	_on_layout_mode_changed(LayoutInfo.layout_mode)

func _on_switch_motors_changed():
	inspector1.select(switch.motor1)
	if inspector2 != null:
		inspector2.select(switch.motor1)

func _on_motor1_selected(motor):
	if switch.motor1 == motor:
		return
	switch.set_motor1(motor)

func _on_motor2_selected(motor):
	if switch.motor2 == motor:
		return
	switch.set_motor2(motor)

func _on_switch_unselected():
	queue_free()
