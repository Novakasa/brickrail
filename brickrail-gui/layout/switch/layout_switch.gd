
class_name LayoutSwitch
extends Reference

var position_index = 0
var motor1 = null
var motor2 = null
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

signal position_changed(pos)
signal state_changed()
signal selected
signal unselected
signal removing(id)
signal motors_changed()

func _init(p_directed_track):
	directed_track = p_directed_track
	switch_positions = directed_track.get_turns()
	switch_positions.sort()
	slot = directed_track.next_slot
	id = "switch_"+directed_track.id
	
	for facing in [1, -1]:
		nodes[facing] = LayoutNode.new(self, id, facing, "switch")

func serialize():
	var struct = {}
	if motor1 != null:
		struct["motor1"] = motor1.serialize_reference()
	if motor2 != null:
		struct["motor2"] = motor2.serialize_reference()
	return struct

func load_struct(struct):
	if "motor1" in struct:
		var motorstruct = struct.motor1
		var controller = Devices.layout_controllers[motorstruct.controller]
		var motor = controller.devices[int(motorstruct.port)]
		set_motor1(motor)
	if "motor2" in struct:
		var motorstruct = struct.motor2
		var controller = Devices.layout_controllers[motorstruct.controller]
		var motor = controller.devices[motorstruct.port]
		set_motor2(motor)

func remove():
	if selected:
		unselect()
	emit_signal("removing", id)

func set_motor1(motor):
	if motor1 != null:
		motor1.disconnect("position_changed", self, "_on_motor1_position_changed")
		motor1.disconnect("responsiveness_changed", self, "_on_motor1_responsiveness_changed")
		motor1.disconnect("removing", self, "_on_motor1_removing")
	motor1 = motor
	
	
	if motor1 == null:
		emit_signal("motors_changed")
		return
		
	if motor1.position != "unknown":
		var pos = dev1_to_pos(motor1.position)
		position_index = switch_positions.find(pos)
		emit_signal("position_changed", pos)
	
	motor1.connect("position_changed", self, "_on_motor1_position_changed")
	motor1.connect("responsiveness_changed", self, "_on_motor1_responsiveness_changed")
	motor1.connect("removing", self, "_on_motor1_removing")
	
	emit_signal("motors_changed")

func set_motor2(motor):
	pass

func _on_motor1_removing(_controllername, _port):
	set_motor1(null)

func _on_motor1_responsiveness_changed(responsiveness):
	disabled = not responsiveness
	prints("switch responsiveness:", responsiveness)
	emit_signal("position_changed", switch_positions[position_index])

func _on_motor1_position_changed(ble_pos):
	var pos = dev1_to_pos(ble_pos)
	position_index = switch_positions.find(pos)
	emit_signal("position_changed", pos)

func hover():
	hover=true
	emit_signal("state_changed")

func stop_hover():
	hover=false
	emit_signal("state_changed")

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
	if motor1 != null and LayoutInfo.control_devices:
		if dev1_to_pos(motor1.position) == pos and motor1.position != "unknown":
			#check only here in case ble switch position is unknown
			pass
		var motor_pos = pos_to_dev1(pos)
		if motor_pos == motor1.position:
			return
		prints("switching motor1:", motor_pos)
		motor1.switch(motor_pos)
		position_index = switch_positions.find(pos)
	else:
		position_index = switch_positions.find(pos)
		emit_signal("position_changed", pos)

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
	emit_signal("state_changed")

func unselect():
	selected=false
	emit_signal("unselected")
	emit_signal("state_changed")

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
