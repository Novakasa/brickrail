
class_name LayoutSwitch
extends RefCounted

var position_index = 0
var motor1 = null
var motor2 = null
var motor1_inverted = false
var motor2_inverted = false
var slot
var switch_positions
var button
var hover=false
var selected=false
var disabled=false
var id
var nodes = {}
var directed_track
var logging_module

var SwitchInspector = preload("res://layout/switch/switch_inspector.tscn")

signal position_changed(pos)
signal state_changed()
signal selected_signal()
signal unselected_signal()
signal removing(id)
signal motors_changed()

func _init(p_directed_track):
	directed_track = p_directed_track
	switch_positions = directed_track.get_turns()
	switch_positions.sort()
	slot = directed_track.next_slot
	id = "switch_"+directed_track.id
	logging_module = id
	
	for facing in [1, -1]:
		nodes[facing] = LayoutNode.new(self, id, facing, "switch")

func serialize():
	var struct = {}
	if motor1 != null:
		struct["motor1"] = motor1.serialize_reference()
	if motor2 != null:
		struct["motor2"] = motor2.serialize_reference()
	struct["motor1_inverted"] = motor1_inverted
	struct["motor2_inverted"] = motor2_inverted
	return struct

func load_struct(struct):
	if "motor1" in struct:
		var motorstruct = struct.motor1
		var controller = Devices.layout_controllers[motorstruct.controller]
		var motor = controller.devices[int(motorstruct.port)]
		if "storage" in motorstruct:
			for key in motorstruct.storage:
				motor.store_value(int(key), motorstruct.storage[key])
		set_motor1(motor)
	if "motor2" in struct:
		var motorstruct = struct.motor2
		var controller = Devices.layout_controllers[motorstruct.controller]
		var motor = controller.devices[motorstruct.port]
		if "storage" in motorstruct:
			for key in motorstruct.storage:
				motor.store_value(int(key), motorstruct.storage[key])
		set_motor2(motor)
	if "motor1_inverted" in struct:
		motor1_inverted = struct.motor1_inverted
	if "motor2_inverted" in struct:
		motor2_inverted = struct.motor2_inverted

func remove():
	if selected:
		deselect()
	emit_signal("removing", id)

func set_motor1(motor):
	if motor1 != null:
		motor1.disconnect("position_changed", Callable(self, "_on_motor1_position_changed"))
		motor1.disconnect("responsiveness_changed", Callable(self, "_on_motor1_responsiveness_changed"))
		motor1.disconnect("removing", Callable(self, "_on_motor1_removing"))
	motor1 = motor
	
	
	if motor1 == null:
		emit_signal("motors_changed")
		return
		
	if motor1.position != "unknown":
		var pos = dev1_to_pos(motor1.position)
		position_index = switch_positions.find(pos)
		emit_signal("position_changed", pos)
	
	motor1.connect("position_changed", Callable(self, "_on_motor1_position_changed"))
	motor1.connect("responsiveness_changed", Callable(self, "_on_motor1_responsiveness_changed"))
	motor1.connect("removing", Callable(self, "_on_motor1_removing"))
	
	emit_signal("motors_changed")

func set_motor2(_motor):
	pass

func _on_motor1_removing(_controllername, _port):
	set_motor1(null)

func _on_motor1_responsiveness_changed(responsiveness):
	disabled = not responsiveness
	emit_signal("position_changed", switch_positions[position_index])

func _on_motor1_position_changed(ble_pos):
	var pos = dev1_to_pos(ble_pos)
	position_index = switch_positions.find(pos)
	emit_signal("position_changed", pos)

func set_hover(_pos):
	hover=true
	emit_signal("state_changed")

func stop_hover():
	hover=false
	emit_signal("state_changed")

func toggle_switch():
	var new_index = (position_index+1) % len(switch_positions)
	switch(switch_positions[new_index])

func pos_to_dev1(pos):
	var dev1_pos = pos
	if dev1_pos=="center":
		if "left" in switch_positions:
			dev1_pos = "right"
		else:
			dev1_pos = "left"
	
	if motor1_inverted:
		if dev1_pos == "left":
			dev1_pos = "right"
		else:
			dev1_pos = "left"
		
	return dev1_pos

func dev1_to_pos(ble_pos):
	if motor1_inverted:
		if ble_pos == "left":
			ble_pos = "right"
		else:
			ble_pos = "left"
	if ble_pos in switch_positions:
		return ble_pos
	return "center"
	
func switch(pos):
	Logger.info("[%s] switch to: %s" % [logging_module, pos])
	if motor1 != null and LayoutInfo.control_devices != LayoutInfo.CONTROL_OFF:
		if dev1_to_pos(motor1.position) == pos and motor1.position != "unknown":
			#check only here in case ble switch position is unknown
			pass
		var motor_pos = pos_to_dev1(pos)
		if motor_pos != motor1.position:
			Logger.info("[%s] switch motor1 to: %s" % [logging_module, motor_pos])
			motor1.switch(motor_pos)
		position_index = switch_positions.find(pos)
	else:
		position_index = switch_positions.find(pos)
	emit_signal("position_changed", pos)

func get_position():
	return switch_positions[position_index]

func process_mouse_button(event, _pos):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if LayoutInfo.layout_mode == "control" and LayoutInfo.control_enabled:
				if directed_track.get_locked() != null:
					return false
				toggle_switch()
				return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			select()
			return true
	return false

func select():
	LayoutInfo.select(self)
	selected=true
	emit_signal("selected")
	emit_signal("state_changed")

func deselect():
	selected=false
	emit_signal("unselected")
	emit_signal("state_changed")

func get_inspector():
	var inspector = SwitchInspector.instantiate()
	inspector.set_switch(self)
	return inspector

func collect_edges(facing):
	var edges = []
	for track in directed_track.get_next_tracks():
		if track.prohibited:
			continue
		var node_obj = track.get_node_obj()
		if track.get_block() != null:
			edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", null))
			continue
		var next_section = LayoutSection.new()
		next_section.collect_segment(track)
		if not facing in next_section.get_allowed_facing_values():
			continue
		node_obj = next_section.tracks[-1].get_node_obj()
		if node_obj == null:
			continue
		edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", next_section))
	return edges
