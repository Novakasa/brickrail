
class_name LayoutSwitch
extends Node2D

var position_index = 0
var ble_switch = null
var slot
var switch_positions
var button
var hover=false

signal position_changed(slot, pos)

func _init(p_slot, positions):
	# text = "switch"
	# connect("pressed", self, "toggle_switch")
	switch_positions = positions
	switch_positions.sort()
	slot = p_slot
	
	position = LayoutInfo.slot_positions[slot]*LayoutInfo.spacing
	# modulate.a=0.0
	# self.connect("pressed", self, "toggle_switch")
	# rect_position = LayoutInfo.slot_positions[slot]*LayoutInfo.spacing - Vector2(0.25,0.25)*LayoutInfo.spacing
	# rect_size = Vector2(0.5,0.5)*LayoutInfo.spacing

func drop_data(position, data):
	prints("dropping switch!", data.name)
	ble_switch = data

func can_drop_data(position, data):
	print("can drop switch!")
	if data is PhysicalSwitch:
		return true
	return false

func hover():
	hover=true
	emit_signal("position_changed", slot, switch_positions[position_index])

func stop_hover():
	hover=false
	emit_signal("position_changed", slot, switch_positions[position_index])

func toggle_switch():
	position_index = (position_index+1) % len(switch_positions)
	switch(switch_positions[position_index])

func switch(pos):
	if ble_switch != null:
		ble_switch.switch(pos)
	else:
		position_index = switch_positions.find(pos)
		emit_signal("position_changed", slot, pos)

func get_position():
	return switch_positions[position_index]

func process_mouse_button(event, pos):
	if LayoutInfo.input_mode != "control":
		return
	var spacing = LayoutInfo.spacing
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_M:
			toggle_switch()
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		toggle_switch()

func _on_ble_switch_position_changed(pos):
	position_index = switch_positions.find(pos)
	emit_signal("position_changed", slot, pos)

func set_ble_switch(p_switch):
	ble_switch = p_switch
	ble_switch.connect("on_position_changed", self, "_on_ble_switch_position_changed")

func _draw():
	var spacing = LayoutInfo.spacing
	var color = Color.red
	color.a = 0.5
	# draw_rect(Rect2(Vector2(-spacing*0.25, -spacing*0.25), Vector2(spacing*0.5, spacing*0.5)), color)
