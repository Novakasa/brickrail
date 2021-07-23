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

var accessories = {}

var TrackInspector = preload("res://track_inspector.tscn")

signal connections_changed
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
	# prints("added connection, turning:", turn)
	track.connect("connections_cleared", self, "_on_track_connections_cleared")
	if len(connections[slot])>1:
		update_switch(slot)
	if initial:
		track.connect_track(get_neighbour_slot(slot), self, false)
	emit_signal("connections_changed", get_orientation())

func update_switch(slot):
	if len(connections[slot])>1:
		if switches[slot] != null:
			switches[slot].queue_free()
			switches[slot] = null
		switches[slot] = LayoutSwitch.new(slot, connections[slot].keys())
		switches[slot].connect("position_changed", self, "_on_switch_position_changed")
		emit_signal("switch_added", switches[slot])
	else:
		if switches[slot] != null:
			switches[slot].queue_free()
			switches[slot] = null

func _on_switch_position_changed(slot, pos):
	emit_signal("switch_position_changed")
	for track in connections[slot].values():
		track.emit_signal("switch_position_changed")

func _on_track_connections_cleared(track):
	disconnect_track(track)

func disconnect_track(track):
	for slot in [slot0, slot1]:
		for turn in connections[slot]:
			if connections[slot][turn] == track:
				disconnect_turn(slot, turn)

func disconnect_turn(slot, turn):
	connections[slot].erase(turn)
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
	if LayoutInfo.input_mode == "draw":
		return
	var hover_candidate = get_switch_at(pos)
	
	if hover_candidate != hover_switch:
		if hover_switch != null:
			hover_switch.stop_hover()
		hover_switch = hover_candidate
		if hover_switch != null:
			hover=false
			hover_switch.hover()
	if hover_candidate != null:
		return
			
	if LayoutInfo.input_mode != "select":
		return
	hover=true
	emit_signal("connections_changed")

func stop_hover():
	hover=false
	if hover_switch != null:
		hover_switch.stop_hover()
		hover_switch = null
	emit_signal("connections_changed")

func select():
	selected_solo=true
	emit_signal("selected", self)
	visual_select()
	LayoutInfo.select(self)

func visual_select():
	selected=true
	emit_signal("connections_changed")

func unselect():
	selected_solo=false
	visual_unselect()
	emit_signal("unselected", self)
	
func visual_unselect():
	selected=false
	emit_signal("connections_changed")

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
		if switch != null:
			switch.process_mouse_button(event, pos)
			return
		
		if LayoutInfo.input_mode == "select":
			LayoutInfo.init_drag_select(self)

func get_inspector():
	var inspector = TrackInspector.instance()
	inspector.set_track(self)
	return inspector
