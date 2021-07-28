class_name LayoutTrack
extends Node

var x_idx
var y_idx
var slot0
var slot1
var pos0
var pos1
var connections = {}
var slots = ["N", "S", "E", "W"]
var route_lock=false
var hover=false
var hover_switch=null
var selected_solo=false
var selected=false

var switches = {}

var metadata = {}
var default_meta = {"selected": false, "hover": false, "block": false}

var TrackInspector = preload("res://track_inspector.tscn")

const STATE_NONE = 0
const STATE_SELECTED = 1
const STATE_HOVER = 2
const STATE_OCCUPIED = 3
const STATE_LOCKED = 4

signal connections_changed(orientation)
signal states_changed(orientation)
signal connections_cleared
signal route_lock_changed(lock)
signal switch_added(switch)
signal switch_position_changed(pos)
signal selected(obj)
signal unselected(obj)
signal removing(orientation)

func _init(p_slot0, p_slot1, i, j):
	slot0 = p_slot0
	slot1 = p_slot1

	assert_slot_degeneracy()
	connections[slot0] = {}
	connections[slot1] = {}
	pos0 = LayoutInfo.slot_positions[slot0]
	pos1 = LayoutInfo.slot_positions[slot1]
	switches[slot0] = null
	switches[slot1] = null
	metadata[slot0] = {"none": default_meta.duplicate()}
	metadata[slot1] = {"none": default_meta.duplicate()}
	
	x_idx = i
	y_idx = j
	
	assert(slot0 != slot1)
	assert(slot0 in slots and slot1 in slots)

func remove():
	clear_connections()
	emit_signal("removing", get_orientation())
	queue_free()

func is_switch(slot=null):
	if slot != null:
		return len(connections[slot]) > 1
	
	return len(connections[slot0]) > 1 or len(connections[slot1]) > 1

func get_turn_from(slot):
	var center_tangent = LayoutInfo.slot_positions[get_neighbour_slot(slot)] - LayoutInfo.slot_positions[slot]
	var tangent = get_slot_tangent(get_opposite_slot(slot))
	var turn_angle = center_tangent.angle_to(tangent)
	if turn_angle > PI:
		turn_angle -= 2*PI
	if is_equal_approx(turn_angle, 0.0):
		return "center"
	if turn_angle > 0.0:
		return "right"
	return "left"

func assert_slot_degeneracy():
	var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]
	if not get_orientation() in orientations:
		var temp = slot0
		slot0 = slot1
		slot1 = temp

func get_orientation():
	return slot0+slot1

func get_direction():
	if get_orientation() in ["NS", "SN"]:
		return 0
	if get_orientation() in ["SE", "ES", "NW", "WN"]:
		return 1
	if get_orientation() in ["EW", "WE"]:
		return 2
	if get_orientation() in ["NE", "EN", "SW", "WS"]:
		return 3

func distance_to(pos):
	var point = Geometry.get_closest_point_to_segment_2d(pos, pos0, pos1)
	return (point-pos).length()

func can_connect_track(slot, track):
	if not slot in connections:
		return false
	if not get_neighbour_slot(slot) in track.connections:
		return false
	if track == self:
		return false
	if track in connections[slot].values():
		return false
	return true

func connect_track(slot, track, initial=true):
	if not slot in connections:
		push_error("[LayoutTrack] can't connect track to a nonexistent slot!")
		return
	if not get_neighbour_slot(slot) in track.connections:
		push_error("[LayoutTrack] can't connect track with a incompatible orientation!")
		return
	if track == self:
		push_error("[LayoutTrack] can't connect track to itself!")
		return
	if track in connections[slot].values():
		push_error("[LayoutTrack] track is already connected at this slot!")
		return
	# prints("connected a track", track.get_orientation(), "with this track", get_orientation())
	var turn = track.get_turn_from(get_neighbour_slot(slot))
	connections[slot][turn] = track
	metadata[slot][turn] = default_meta.duplicate()
	# prints("added connection, turning:", turn)
	track.connect("connections_cleared", self, "_on_track_connections_cleared")
	if len(connections[slot])>1:
		update_switch(slot)
	if initial:
		track.connect_track(get_neighbour_slot(slot), self, false)
	emit_signal("connections_changed", get_orientation())
	emit_signal("states_changed", get_orientation())

func update_switch(slot):
	if len(connections[slot])>1:
		if switches[slot] != null:
			switches[slot].queue_free()
			switches[slot] = null
		switches[slot] = LayoutSwitch.new(slot, connections[slot].keys())
		switches[slot].connect("position_changed", self, "_on_switch_position_changed")
		switches[slot].connect("state_changed", self, "_on_switch_state_changed")
		emit_signal("switch_added", switches[slot])
		_on_switch_position_changed(slot, switches[slot].get_position())
		add_child(switches[slot])
	else:
		if switches[slot] != null:
			switches[slot].queue_free()
			switches[slot] = null

func _on_switch_state_changed(slot):
	emit_signal("states_changed", get_orientation())
	for track in connections[slot].values():
		track.emit_signal("states_changed", track.get_orientation())

func _on_switch_position_changed(slot, pos):
	emit_signal("connections_changed", get_orientation())
	for track in connections[slot].values():
		track.emit_signal("connections_changed", track.get_orientation())

func get_switch(slot):
	return switches[slot]

func get_opposite_switch(slot, turn):
	var to_track = connections[slot][turn]
	return to_track.switches[to_track.get_neighbour_slot(slot)]

func get_connection_switches(slot, turn):
	var switch_list = []
	if switches[slot] != null:
		switch_list.append(switches[slot])
	var opposite_switch = get_opposite_switch(slot, turn)
	if opposite_switch != null:
		switch_list.append(opposite_switch)
	return switch_list

func _on_track_connections_cleared(track):
	disconnect_track(track)

func disconnect_track(track):
	for slot in [slot0, slot1]:
		for turn in connections[slot]:
			if connections[slot][turn] == track:
				disconnect_turn(slot, turn)

func disconnect_turn(slot, turn):
	connections[slot].erase(turn)
	metadata[slot].erase(turn)
	if len(connections[slot]) > 0:
		update_switch(slot)
	emit_signal("connections_changed", get_orientation())

func clear_connections():
	for slot in [slot0, slot1]:
		for turn in connections[slot]:
			disconnect_turn(slot, turn)
	emit_signal("connections_cleared", self)

func get_neighbour_slot(slot):
	if slot == "N":
		return "S"
	if slot == "S":
		return "N"
	if slot == "E":
		return "W"
	if slot == "W":
		return "E"

func get_opposite_slot(slot):
	if slot0 == slot:
		return slot1
	elif slot1 == slot:
		return slot0
	push_error("[LayoutTrack.get_opposite_slot] track doesn't contain " + slot)

func get_connected_slot(track):
	for slot in connections:
		if track in connections[slot].values():
			return slot
	return null

func get_connection_to(track):
	for slot in connections:
		if track in connections[slot].values():
			var turn = track.get_turn_from(get_neighbour_slot(slot))
			return {"slot": slot, "turn": turn}
	assert(false)

func get_next_tracks_from(slot):
	return get_next_tracks_at(get_opposite_slot(slot))

func directed_iter(neighbour_to):
	var to_slot = get_opposite_slot(get_neighbour_slot(neighbour_to))
	return [to_slot, connections[to_slot]]
	
func get_next_tracks_at(slot):
	return connections[slot]
	push_error("[LayoutTrack.get_next_tracks_at] track doesn't contain " + slot)

func get_circle_arc_segment(center, radius, num, start, end):
	var segments = PoolVector2Array()
	var delta = (end-start)/num
	var p1
	for i in range(num):
		var alpha0 = start + i*delta
		var alpha1 = alpha0 + delta
		var p0 = center + radius*Vector2(cos(alpha0), sin(alpha0))
		segments.append(p0)
		p1 = center + radius*Vector2(cos(alpha1), sin(alpha1))
	segments.append(p1)
	return segments

func get_slot_tangent(slot):
	if slot == slot1:
		return pos1-pos0
	return pos0-pos1

func get_slot_pos(slot):
	if slot == slot1:
		return pos1
	return pos0

func has_point(pos):
	pass
	
func get_switch_at(pos):
	for slot in switches:
		if switches[slot] != null:
			if (LayoutInfo.slot_positions[slot]-pos).length() < 0.3:
				return switches[slot]
	return null

func hover(pos):

	var hover_candidate = get_switch_at(pos)
	if LayoutInfo.input_mode == "draw":
		hover_candidate = null
	
	if hover_candidate != hover_switch:
		if hover_switch != null:
			hover_switch.stop_hover()
		hover_switch = hover_candidate
		if hover_switch != null:
			set_connection_attribute(slot0, "none", "hover", false)
			set_connection_attribute(slot1, "none", "hover", false)
			emit_signal("states_changed", get_orientation())
			hover_switch.hover()
	if hover_candidate != null:
		return

	set_connection_attribute(slot0, "none", "hover", true)
	set_connection_attribute(slot1, "none", "hover", true)
	emit_signal("states_changed", get_orientation())

func stop_hover():
	set_connection_attribute(slot0, "none", "hover", false)
	set_connection_attribute(slot1, "none", "hover", false)
	if hover_switch != null:
		hover_switch.stop_hover()
		hover_switch = null
	emit_signal("states_changed", get_orientation())

func select():
	selected_solo=true
	emit_signal("selected", self)
	visual_select()
	LayoutInfo.select(self)

func visual_select():
	set_connection_attribute(slot0, "none", "selected", true)
	set_connection_attribute(slot1, "none", "selected", true)
	emit_signal("states_changed", get_orientation())

func unselect():
	selected_solo=false
	visual_unselect()
	emit_signal("unselected", self)
	
func visual_unselect():
	set_connection_attribute(slot1, "none", "selected", false)
	emit_signal("states_changed", get_orientation())

func _unhandled_input(event):
	if event is InputEventKey:
		if event.scancode == KEY_DELETE and event.pressed:
			if selected_solo:
				for slot in connections:
					for track in connections[slot].values():
						track.call_deferred("select")
				remove()

func process_mouse_button(event, pos):
	if event.button_index == BUTTON_LEFT and event.pressed:
		var switch = get_switch_at(pos)
		if LayoutInfo.input_mode == "draw":
			switch = null
		if switch != null:
			switch.process_mouse_button(event, pos)
			return
		
		if LayoutInfo.input_mode == "select":
			LayoutInfo.init_drag_select(self)
		
		if LayoutInfo.input_mode == "draw":
			LayoutInfo.init_connected_draw_track(self)

func get_inspector():
	var inspector = TrackInspector.instance()
	inspector.set_track(self)
	return inspector

func set_connection_attribute(slot, turn, key, value):
	metadata[slot][turn][key] = value
	emit_signal("states_changed", get_orientation())

func set_track_connection_attribute(track, key, value):
	var connection = get_connection_to(track)
	set_connection_attribute(connection.slot, connection.turn, key, value)

func get_shader_connection_flags(to_slot):
	if len(connections[to_slot]) == 0:
		return 8

	var turn_flags = {"left": 1, "center": 2, "right": 4}
	var position_flags = {"left": 16, "center": 32, "right": 64}
	var position_flags_priority = {"left": 128, "center": 256, "right": 512}
	var connection_flags = 0
	for turn in connections[to_slot]:
		connection_flags |= turn_flags[turn]
		
		var opposite_switch = get_opposite_switch(to_slot, turn)
		var opposite_turn = get_turn_from(to_slot)
		if opposite_switch != null:
			if opposite_turn == opposite_switch.get_position():
				connection_flags |= position_flags[turn]

	if switches[to_slot] != null:
		connection_flags |= position_flags[switches[to_slot].get_position()]
		if not switches[to_slot].disabled:
			connection_flags |= position_flags_priority[switches[to_slot].get_position()]
	
	return connection_flags

func get_shader_states(to_slot):
	var states = {"left": 0, "right": 0, "center": 0, "none": 0}
	for turn in metadata[to_slot]:
		if turn != "none":
			var switches = get_connection_switches(to_slot, turn)
			for switch in switches:
				if switch.selected:
					states[turn] = max(states[turn], STATE_SELECTED)
				if switch.hover:
					states[turn] = max(states[turn], STATE_HOVER)
		if metadata[to_slot][turn]["selected"]:
			states[turn] = max(states[turn], STATE_SELECTED)
		if metadata[to_slot][turn]["hover"]:
			states[turn] = max(states[turn], STATE_HOVER)
	return states
