class_name LayoutTrack
extends Node2D

const STATE_SELECTED = 1
const STATE_HOVER = 2
const STATE_LOCKED = 4
const STATE_BLOCK = 8
const STATE_BLOCK_OCCUPIED = 16
const STATE_BLOCK_HOVER = 32
const STATE_BLOCK_SELECTED = 64
const STATE_BLOCK_PLUS = 2048
const STATE_BLOCK_MINUS = 4096
const STATE_CONNECTED = 128
const STATE_SWITCH = 256
const STATE_SWITCH_PRIORITY = 512
const STATE_ARROW = 1024
const STATE_MARK = 8192
const STATE_PORTAL = 16384
const STATE_STOPPER = 32768

var l_idx
var x_idx
var y_idx
var slot0
var slot1
var id
var pos0
var pos1
var slots = ["N", "S", "E", "W"]
var route_lock=false
var hover_obj = null
var drawing_highlight=false

var directed_tracks = {}
var sensor = null

signal connections_changed(orientation)
signal states_changed(orientation)
signal connections_cleared
signal route_lock_changed(lock)
signal selected(obj)
signal unselected(obj)
signal removing(orientation)
signal sensor_changed(track)

func _init(p_slot0, p_slot1, l, i, j):
	
	slot0 = p_slot0
	slot1 = p_slot1
	assert_slot_degeneracy()
	
	l_idx = l
	x_idx = i
	y_idx = j
	id = "track_"+str(l_idx)+"_"+str(x_idx)+"_"+str(y_idx)+"_"+get_orientation()

	pos0 = LayoutInfo.slot_positions[slot0]
	pos1 = LayoutInfo.slot_positions[slot1]

	directed_tracks[slot0] = DirectedLayoutTrack.new(slot1, slot0, id, l_idx, x_idx, y_idx)
	directed_tracks[slot0].connect("states_changed", self, "_on_dirtrack_states_changed")
	directed_tracks[slot0].connect("add_sensor_requested", self, "add_sensor")
	directed_tracks[slot0].connect("remove_requested", self, "remove")
	directed_tracks[slot1] = DirectedLayoutTrack.new(slot0, slot1, id, l_idx, x_idx, y_idx)
	directed_tracks[slot1].connect("states_changed", self, "_on_dirtrack_states_changed")
	directed_tracks[slot1].connect("add_sensor_requested", self, "add_sensor")
	directed_tracks[slot1].connect("remove_requested", self, "remove")
	
	directed_tracks[slot0].set_opposite(directed_tracks[slot1])
	directed_tracks[slot1].set_opposite(directed_tracks[slot0])
	
	assert(slot0 != slot1)
	assert(slot0 in slots and slot1 in slots)

func _on_dirtrack_states_changed(slot):
	emit_signal("states_changed", get_orientation())

func get_directed_to(slot):
	return directed_tracks[slot]

func get_directed_from(slot):
	return directed_tracks[get_opposite_slot(slot)]

func get_dirtracks():
	return directed_tracks.values()

func serialize(reference=false):
	var result = {}
	result["l_idx"] = l_idx
	result["x_idx"] = x_idx
	result["y_idx"] = y_idx
	var connections_result = {}
	var switches_struct = {}
	if not reference:
		for slot in directed_tracks:
			var dirtrack = directed_tracks[slot]
			connections_result[slot] = []
			for turn in dirtrack.connections:
				connections_result[slot].append(turn)
			if dirtrack.switch != null:
				switches_struct[slot] = dirtrack.switch.serialize()
				
		result["connections"] = connections_result
		if len(switches_struct) > 0:
			result["switches"] = switches_struct
		
		if sensor != null:
			result["sensor"] = sensor.serialize()
		
		for slot in directed_tracks:
			if directed_tracks[slot].prohibited:
				result["prohibited_slot"] = slot
				break
	else:
		result["orientation"] = get_orientation()
	return result

func get_block():
	for dirtrack in directed_tracks.values():
		for turn in dirtrack.metadata:
			if dirtrack.metadata[turn]["block"]!=null:
				return LayoutInfo.blocks[dirtrack.metadata[turn]["block"]]
	return null

func get_logical_block():
	var block = get_block()
	if block == null:
		return null
	if block.logical_blocks[0].section.get_track_index(self)>=(len(block.section.tracks)/2):
		return block.logical_blocks[0]
	return block.logical_blocks[1]

func get_cell():
	return LayoutInfo.cells[l_idx][x_idx][y_idx]

func get_center():
	return (pos0 + pos1)*0.5

func get_tangent():
	return (pos1-pos0).normalized()

func collides_with(track):
	assert(track.x_idx == x_idx and track.y_idx == y_idx)
	if track.slot0 in  [slot0, slot1] or track.slot1 in [slot0, slot1]:
		return true
	if is_zero_approx(track.get_tangent().dot(get_tangent())):
		return true
	return false

func load_connections(struct):
	for slot in struct:
		for turn in struct[slot]:
			var track = get_slot_cell(slot).get_turn_track_from(get_neighbour_slot(slot), turn)
			connect_track(slot, track)

func load_switches(struct):
	for slot in struct:
		assert(directed_tracks[slot].switch != null)
		directed_tracks[slot].switch.load_struct(struct[slot])
		
func get_slot_cell(slot):
	if slot=="N":
		return LayoutInfo.get_cell(l_idx, x_idx, y_idx-1)
	if slot=="S":
		return LayoutInfo.get_cell(l_idx, x_idx, y_idx+1)
	if slot=="W":
		return LayoutInfo.get_cell(l_idx, x_idx-1, y_idx)
	if slot=="E":
		return LayoutInfo.get_cell(l_idx, x_idx+1, y_idx)

func remove():
	clear_connections()
	emit_signal("removing", get_orientation())
	queue_free()

func is_switch(slot=null):
	if slot != null:
		return len(directed_tracks[slot].connections) > 1
	
	return len(directed_tracks[slot].connections) > 1 or len(directed_tracks[slot].connections) > 1

func get_turn_from(slot):
	return directed_tracks[slot].get_opposite().get_turn()

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

func is_connected_to_track(track):
	for dirtrack in directed_tracks.values():
		for other_dirtrack in track.directed_tracks.values():
			if other_dirtrack in dirtrack.connections.values():
				return true
	return false

func can_connect_track(slot, track):
	if not slot in directed_tracks:
		return false
	if not get_neighbour_slot(slot) in track.directed_tracks:
		return false
	if track == self:
		return false
	if is_connected_to_track(track):
		return false
	return true

func connect_track(slot, track, initial=true):
	if not slot in directed_tracks:
		push_error("[LayoutTrack] can't connect track to a nonexistent slot!")
		return
	if not get_neighbour_slot(slot) in track.directed_tracks:
		push_error("[LayoutTrack] can't connect track with incompatible orientation!")
		return
	if track == self:
		push_error("[LayoutTrack] can't connect track to itself!")
		return
	if is_connected_to_track(track):
		push_error("[LayoutTrack] track is already connected at this slot!")
		return

	var neighbour_slot = get_neighbour_slot(slot)
	var turn = track.get_turn_from(neighbour_slot)
	var dirtrack = track.get_directed_from(neighbour_slot)
	
	directed_tracks[slot].connect_dirtrack(turn, dirtrack)
	
	track.connect("connections_cleared", self, "_on_track_connections_cleared")
	if initial:
		track.connect_track(neighbour_slot, self, false)
	emit_signal("connections_changed", get_orientation())
	emit_signal("states_changed", get_orientation())

func has_switch():
	return directed_tracks[slot0].switch != null or directed_tracks[slot1].switch != null

func borders_switch():
	for dirtrack in directed_tracks.values():
		for connected in dirtrack.connections.values():
			if connected.get_opposite().switch != null:
				return true
	return false

func get_switch(slot):
	return directed_tracks[slot].switch()

func get_opposite_switch(slot, turn):
	return directed_tracks[slot].get_opposite_switch(turn)

func get_connection_switches(slot, turn):
	var switch_list = []
	if directed_tracks[slot].switch != null:
		switch_list.append(directed_tracks[slot].switch)
	var opposite_switch = get_opposite_switch(slot, turn)
	if opposite_switch != null:
		switch_list.append(opposite_switch)
	return switch_list

func set_switch_to_track(track):
	var connection = get_connection_to(track)
	if directed_tracks[connection.slot].switch==null:
		return
	directed_tracks[connection.slot].switch.switch(connection.turn)

func _on_track_connections_cleared(track):
	disconnect_track(track)

func disconnect_track(track):
	for dirtrack in directed_tracks.values():
		for turn in dirtrack.connections:
			if dirtrack.connections[turn] in track.directed_tracks.values():
				dirtrack.disconnect_turn(turn)

func has_connection_at(slot):
	return len(directed_tracks[slot].connections)>0

func clear_connections():
	for dirtrack in directed_tracks.values():
		for turn in dirtrack.connections:
			var opposite_turn = dirtrack.get_opposite().get_turn()
			dirtrack.connections[turn].get_opposite().disconnect_turn(opposite_turn)
			dirtrack.disconnect_turn(turn)
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
	for slot in directed_tracks:
		var dirtrack = directed_tracks[slot]
		for other_dirtrack in track.directed_tracks.values():
			if other_dirtrack in dirtrack.connections.values():
				return slot
	return null

func get_connection_to(track):
	for slot in directed_tracks:
		var dirtrack = directed_tracks[slot]
		for turn in dirtrack.connections:
			if dirtrack.connections[turn] in track.directed_tracks.values():
				return {"slot": slot, "turn": turn}
	return null

func get_slot_tangent(slot):
	if slot == slot1:
		return pos1-pos0
	return pos0-pos1

func get_slot_pos(slot):
	return LayoutInfo.slot_positions[slot]

func has_point(pos):
	pass

func get_switches():
	var switches = []
	for dirtrack in directed_tracks.values():
		if dirtrack.get_switch() != null:
			switches.append(dirtrack.get_switch())
	return switches

func get_locked():
	var locked = []
	for dirtrack in directed_tracks.values():
		for data in dirtrack.metadata.values():
			var val = data["locked"]
			if val != null and not val in locked:
				locked.append(val)
	return locked

func add_sensor(p_sensor):
	set_sensor(p_sensor)

func set_sensor(p_sensor):
	if sensor != null:
		sensor.disconnect("marker_color_changed", self, "_on_sensor_marker_color_changed")
		
	sensor = p_sensor
	for dirtrack in directed_tracks.values():
		dirtrack.set_sensor(sensor)
	
	if sensor != null:
		sensor.connect("marker_color_changed", self, "_on_sensor_marker_color_changed")
	
	emit_signal("states_changed", get_orientation())
	emit_signal("sensor_changed", self)
	update()

func load_sensor(struct):
	add_sensor(LayoutSensor.new())
	sensor.load(struct)

func _on_sensor_marker_color_changed():
	update()
	emit_signal("states_changed", get_orientation())

func remove_sensor():
	set_sensor(null)

func set_drawing_highlight(highlight):
	drawing_highlight = highlight
	emit_signal("states_changed", get_orientation())

func get_switch_at(pos):
	for slot in directed_tracks:
		if directed_tracks[slot].get_switch() != null:
			if (LayoutInfo.slot_positions[slot]-pos).length() < 0.3:
				return directed_tracks[slot].get_switch()
	return null

func get_hover_obj_at(pos):
	var hover_switch = get_switch_at(pos)
	if hover_switch != null:
		return hover_switch
	if LayoutInfo.input_mode=="control":
		return null
	if (pos-pos0).length()<(pos-pos1).length():
		return directed_tracks[slot0]
	return directed_tracks[slot1]

func hover(pos):

	var hover_candidate = get_hover_obj_at(pos)
	if LayoutInfo.drawing_track:
		hover_candidate = null
	
	if hover_candidate != hover_obj:
		if hover_obj != null:
			hover_obj.stop_hover()
		hover_obj = hover_candidate
		if hover_obj != null:
			hover_obj.hover(pos)

func stop_hover():
	if hover_obj != null:
		hover_obj.stop_hover()
		hover_obj = null
	emit_signal("states_changed", get_orientation())

func process_mouse_button(event, pos):
	if event.button_index == BUTTON_RIGHT and event.pressed:
		if LayoutInfo.input_mode == "draw":
			remove()
	
	if event.button_index == BUTTON_LEFT and event.pressed:
		var switch = get_switch_at(pos)
		if LayoutInfo.input_mode == "draw":
			switch = null
		if switch != null:
			switch.process_mouse_button(event, pos)
			return
		
		if LayoutInfo.input_mode == "select":
			if (pos0-pos).length()<(pos1-pos).length():
				LayoutInfo.init_drag_select(self, slot0)
			else:
				LayoutInfo.init_drag_select(self, slot1)
		
		if LayoutInfo.input_mode == "draw":
			LayoutInfo.init_connected_draw_track(self)
		
		if LayoutInfo.input_mode == "portal":
			if (pos0-pos).length()<(pos1-pos).length():
				LayoutInfo.set_portal_target(directed_tracks[slot0])
			else:
				LayoutInfo.set_portal_target(directed_tracks[slot1])

func get_tangent_to(slot):
	if slot == slot1:
		return get_tangent()
	return -get_tangent()

func get_shader_states(slot):
	var states = directed_tracks[slot].get_shader_states()
	if drawing_highlight:
		states["none"] |= STATE_SELECTED
	return states

func _draw():
	if sensor != null:
		var color = sensor.get_color()
		draw_circle(get_center()*LayoutInfo.spacing, 0.05*LayoutInfo.spacing, color)
