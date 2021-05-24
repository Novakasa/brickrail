extends VBoxContainer

export(NodePath) var input_control_button
export(NodePath) var input_select_button
export(NodePath) var input_draw_button

func _ready():
	LayoutInfo.connect("input_mode_changed", self, "_on_input_mode_changed")

func _on_input_mode_changed(mode):
	var buttons = {
		"control": get_node(input_control_button),
		"select": get_node(input_select_button),
		"draw": get_node(input_draw_button)
		}
	for key in buttons:
		if key == mode:
			buttons[key].disabled=true
		else:
			buttons[key].disabled=false

func _on_LayoutControl_pressed():
	LayoutInfo.set_input_mode("control")


func _on_LayoutSelect_pressed():
	LayoutInfo.set_input_mode("select")


func _on_LayoutDraw_pressed():
	LayoutInfo.set_input_mode("draw")
