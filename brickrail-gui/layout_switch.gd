
class_name LayoutSwitch
extends Node2D

var position_index = 0
var ble_switch = null
var slot
var switch_positions
var button
var hover=false
var selected=false
var disabled=false

var SwitchInspector = preload("res://switch_inspector.tscn")

signal position_changed(slot, pos)
signal state_changed(slot)
signal selected
signal unselected

func _init(p_slot, positions):
	switch_positions = positions
	switch_positions.sort()
	slot = p_slot
	
	position = LayoutInfo.slot_positions[slot]*LayoutInfo.spacing


func drop_data(position, data):
	prints("dropping switch!", data.name)
	ble_switch = data

func can_drop_data(position, data):
	print("can drop switch!")
	if data is PhysicalSwitch:
		return true
	return false

func set_ble_switch(p_ble_switch):
	if ble_switch != null:
		ble_switch.disconnect("position_changed", self, "_on_ble_switch_position_changed")
		ble_switch.disconnect("hub_responsiveness_changed", self, "_on_ble_switch_responsiveness_changed")
	ble_switch = p_ble_switch
	if ble_switch.position != "unkown":
		var pos = dev1_to_pos(ble_switch.position)
		position_index = switch_positions.find(pos)
		emit_signal("position_changed", slot, pos)
	ble_switch.connect("position_changed", self, "_on_ble_switch_position_changed")
	ble_switch.connect("responsiveness_changed", self, "_on_ble_switch_responsiveness_changed")

func _on_ble_switch_responsiveness_changed(responsiveness):
	disabled = not responsiveness
	prints("switch responsiveness:", responsiveness)
	emit_signal("position_changed", slot, switch_positions[position_index])

func _on_ble_switch_position_changed(ble_pos):
	var pos = dev1_to_pos(ble_pos)
	position_index = switch_positions.find(pos)
	emit_signal("position_changed", slot, pos)

func hover():
	hover=true
	emit_signal("state_changed", slot)

func stop_hover():
	hover=false
	emit_signal("state_changed", slot)

func toggle_switch():
	var new_index = (position_index+1) % len(switch_positions)
	switch(switch_positions[new_index])

func pos_to_dev1(pos):
	if pos=="center":
		if "left" in switch_positions:
			return "right"
		return "left"
		
	return pos

func dev1_to_pos(ble_pos):
	if ble_pos in switch_positions:
		return ble_pos
	return "center"
	
func switch(pos):
	if ble_switch != null:
		var ble_pos = pos_to_dev1(pos)
		prints("switching ble_switch:", ble_pos)
		ble_switch.switch(ble_pos)
	else:
		position_index = switch_positions.find(pos)
		emit_signal("position_changed", slot, pos)

func get_position():
	return switch_positions[position_index]

func process_mouse_button(event, pos):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		if LayoutInfo.input_mode == "control":
			toggle_switch()
		if LayoutInfo.input_mode == "select":
			select()

func select():
	LayoutInfo.select(self)
	selected=true
	emit_signal("selected")
	emit_signal("state_changed", slot)

func unselect():
	selected=false
	emit_signal("unselected")
	emit_signal("state_changed", slot)

func get_inspector():
	var inspector = SwitchInspector.instance()
	inspector.set_switch(self)
	return inspector
