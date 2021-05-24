class_name LayoutCell
extends Node2D

var x_idx
var y_idx
var tracks = {}
var hover_track = null

onready var track_material = preload("res://layout_cell_shader.tres")

func _init(p_x_idx, p_y_idx):
	x_idx = p_x_idx
	y_idx = p_y_idx
	
	position = Vector2(x_idx, y_idx)*LayoutInfo.spacing
	
func _ready():
	material = track_material.duplicate()
	_on_track_connections_changed()

func hover_at(pos):
	var normalized_pos = pos/LayoutInfo.spacing
	var hover_candidate = null
	hover_candidate = get_track_at(normalized_pos)
	if hover_candidate != hover_track and hover_track != null:
		hover_track.stop_hover()
	hover_track = hover_candidate
	if hover_track != null:
		hover_track.hover(normalized_pos)

func stop_hover():
	if hover_track != null:
		hover_track.stop_hover()
		hover_track = null

func process_mouse_button(event, pos):
	var normalized_pos = pos/LayoutInfo.spacing
	var track = get_track_at(normalized_pos)
	if track != null:
		track.process_mouse_button(event, normalized_pos)

func get_track_at(normalized_pos):
	var i = 0
	var closest_dist = LayoutInfo.spacing+1
	var closest_track = null
	for track in tracks.values():
		var dist = track.distance_to(normalized_pos)
		if dist<closest_dist:
			closest_track = track
			closest_dist = dist
	if closest_dist > 0.2:
		return null
	return closest_track

func create_track_at(pos, direction=null):
	var i = 0
	var closest_dist = LayoutInfo.spacing+1
	var closest_track = null
	var normalized_pos = pos/LayoutInfo.spacing
	for orientation in LayoutInfo.orientations:
		var track = LayoutTrack.new(orientation[0], orientation[1])
		if direction!= null:
			if track.get_direction()!=direction:
				continue
		var dist = track.distance_to(normalized_pos)
		if dist<closest_dist:
			closest_track = track
			closest_dist = dist
	return closest_track

func get_slot_to_cell(cell):
	if cell.x_idx == x_idx+1 and cell.y_idx == y_idx:
		return "E"
	if cell.x_idx == x_idx-1 and cell.y_idx == y_idx:
		return "W"
	if cell.x_idx == x_idx and cell.y_idx == y_idx+1:
		return "S"
	if cell.x_idx == x_idx and cell.y_idx == y_idx-1:
		return "N"
	return null
	
func create_track(slot0, slot1):
	var track = LayoutTrack.new(slot0, slot1)
	return track
	
func add_track(track):
	if track.get_orientation() in tracks:
		print("can't add track, same orientation already occupied!")
		return tracks[track.get_orientation()]
	tracks[track.get_orientation()] = track
	track.connect("connections_changed", self, "_on_track_connections_changed")
	track.connect("switch_added", self, "_on_track_switch_added")
	track.connect("switch_position_changed", self, "_on_track_connections_changed")
	update()
	_on_track_connections_changed()
	return track

func clear():
	for track in tracks.values():
		track.clear_connections()
	tracks.clear()
	_on_track_connections_changed()

func _on_track_switch_added(switch):
	pass

func _on_track_connections_changed(orientation=null):
	var vecs = []
	var turn_flags = {"left": 1, "center": 2, "right": 4}
	var position_flags = {"left": 16, "center": 32, "right": 64}
	var position_flags_priority = {"left": 128, "center": 256, "right": 512}
	var selected_flags = {"left": 1024, "center": 2048, "right": 4096}
	var hover_flags = {"left": 8192, "center": 16384, "right": 32768}
	
	for from_id in range(4):
		vecs.append(Vector3())
	for track in tracks.values():
		for to_slot in [track.slot0, track.slot1]:
			var from_slot = track.get_opposite_slot(to_slot)
			var to_slot_id = LayoutInfo.slot_index[to_slot]
			var from_slot_id = LayoutInfo.slot_index[from_slot]

			var connections = 0
			for turn in track.connections[to_slot]:
				connections |= turn_flags[turn]
				
				var to_track = track.connections[to_slot][turn]
				var to_track_from_slot = to_track.get_neighbour_slot(to_slot)
				# print(track.get_turn_from(to_slot))
				# print(to_track.switch_positions[to_track_from_slot])
				var opposite_switch = to_track.switches[to_track_from_slot]
				var opposite_turn = track.get_turn_from(to_slot)
				if opposite_switch != null:
					if opposite_switch.hover:
						if track == to_track.connections[to_track_from_slot][opposite_turn]:
							connections |= hover_flags[turn]
					if opposite_switch.selected:
						if track == to_track.connections[to_track_from_slot][opposite_turn]:
							connections |= selected_flags[turn]
					if opposite_turn == opposite_switch.get_position():
						connections |= position_flags[turn]
				# prints(connections, from_slot, to_slot, turn)
				if track.switches[to_slot] != null:
					if track.switches[to_slot].hover:
						connections |= hover_flags[turn]
					if track.switches[to_slot].selected:
						connections |= selected_flags[turn]
				
				if track.hover:
					connections |= hover_flags[turn]

			if track.switches[to_slot] != null:
				connections |= position_flags[track.switches[to_slot].get_position()]
				if not track.switches[to_slot].disabled:
					connections |= position_flags_priority[track.switches[to_slot].get_position()]
			
			if len(track.connections[to_slot]) == 0:
				connections = 8
			
			if to_slot_id == 3:
				to_slot_id = from_slot_id
			# prints(from_slot, to_slot, "final connection:", connections, from_slot_id, to_slot_id)
			vecs[from_slot_id][to_slot_id] = connections
	var connections_matrix = Transform(vecs[0], vecs[1], vecs[2], vecs[3])
	material.set_shader_param("connections", connections_matrix)
	# update()

func _draw():
	var spacing = LayoutInfo.spacing
	draw_rect(Rect2(Vector2(0,0), Vector2(spacing, spacing)), Color.black)
