
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
var id
var nodes = {}
var directed_track

var SwitchInspector = preload("res://layout/switch/switch_inspector.tscn")

signal position_changed(slot, pos)
signal state_changed(slot)
signal selected
signal unselected
signal removing(id)

func _init(p_directed_track):
	directed_track = p_directed_track
	switch_positions = directed_track.get_turns()
	switch_positions.sort()
	slot = directed_track.next_slot
	id = "switch_"+directed_track.id
	
	for facing in [1, -1]:
		nodes[facing] = LayoutNode.new(self, id, facing, "switch")
	
	position = LayoutInfo.slot_positions[slot]*LayoutInfo.spacing

func serialize():
	var struct = {}
	var ble_switch_name = null
	if ble_switch != null:
		ble_switch_name = ble_switch.name
	struct["ble_switch"] = ble_switch_name
	return struct

func remove():
	if selected:
		unselect()
	emit_signal("removing", id)
	queue_free()

func drop_data(position, data):
	prints("dropping switch!", data.name)
	ble_switch = data

func can_drop_data(position, data):
	print("can drop switch!")
	if data is BLESwitch:
		return true
	return false

func set_ble_switch(p_ble_switch):
	if ble_switch != null:
		ble_switch.disconnect("position_changed", self, "_on_ble_switch_position_changed")
		ble_switch.disconnect("hub_responsiveness_changed", self, "_on_ble_switch_responsiveness_changed")
	ble_switch = p_ble_switch
	if ble_switch.position != "unknown":
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
	if ble_switch != null and LayoutInfo.control_devices:
		if dev1_to_pos(ble_switch.position) == pos and ble_switch.position != "unknown":
			#check only here in case ble switch position is unknown
			pass
		var ble_pos = pos_to_dev1(pos)
		prints("switching ble_switch:", ble_pos)
		ble_switch.switch(ble_pos)
		position_index = switch_positions.find(pos)
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

func collect_edges(facing):
	var edges = []
	for track in directed_track.get_next_tracks():
		
		var node_obj = track.get_block()
		if node_obj != null:
			edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", null))
			continue
		var next_section = LayoutSection.new()
		next_section.collect_segment(track)
		node_obj = next_section.tracks[-1].get_node_obj()
		if node_obj == null:
			continue
		edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", next_section))
	return edges
