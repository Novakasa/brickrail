class_name DirectedLayoutTrack
extends Reference

var track
var next_slot
var prev_slot
var next_pos
var prev_pos
var id

func _init(p_track, p_next_slot):
	track = p_track
	next_slot = p_next_slot
	prev_slot = track.get_opposite_slot(next_slot)
	id = p_track.id + "_>"+next_slot
	next_pos = LayoutInfo.slot_positions[next_slot]
	prev_pos = LayoutInfo.slot_positions[prev_slot]

func get_rotation():
	return (next_pos-prev_pos).angle()

func get_turns():
	return track.connections[next_slot].keys()

func get_next_in_segment():
	var next_track = track.get_next_track(next_slot, true)
	if next_track == null:
		return null
	var next_prev_slot = track.get_neighbour_slot(next_slot)
	return next_track.get_directed_from(next_prev_slot)

func get_next(turn=null):
	if turn==null:
		turn = get_next_turn()
		if turn==null:
			return null
	var next = track.connections[next_slot][turn]
	var next_prev_slot = track.get_neighbour_slot(next_slot)
	return next.get_directed_from(next_prev_slot)

func get_next_turn():
	if len(track.connections[next_slot])==0:
		return null
	if len(track.connections[next_slot])>1:
		return get_switch().get_position()
	return track.connections[next_slot].keys()[0]

func get_connection_length(turn=null):
	if turn == null:
		turn = get_next_turn()
	var next = get_next(turn)
	var this_length = track.get_connection_length(next_slot, turn)
	var reverse_connection = next.track.get_connection_to(track)
	var next_length = next.track.get_connection_length(reverse_connection.slot, reverse_connection.turn)
	return this_length + next_length

func interpolate(pos, turn=null):
	var next = get_next(turn)
	return track.interpolate_track_connection(next.track, pos)

func to_world(vec):
	return LayoutInfo.spacing*(Vector2(track.x_idx, track.y_idx)+vec)

func get_next_tracks():
	var next_tracks = []
	for next_track in track.connections[next_slot].values():
		next_tracks.append(next_track.get_directed_from(track.get_neighbour_slot(next_slot)))
	return next_tracks

func set_connection_attribute(slot, turn, key, value, operation):
	track.set_connection_attribute(slot, turn, key, value, operation)

func set_track_connection_attribute(to_track, key, value, operation):
	track.set_track_connection_attribute(to_track.track, key, value, operation)

func get_switch():
	return track.switches[next_slot]

func get_switches():
	var switches = []
	if track.switches[next_slot]!=null:
		switches.append(track.switches[next_slot])
	if track.switches[prev_slot]!=null:
		switches.append(track.switches[prev_slot])
	return switches
	

func get_opposite():
	return track.get_directed_from(next_slot)

func get_block():
	var block = track.get_block()
	if block == null:
		return null
	for logical_block in block.logical_blocks:
		if self in logical_block.section.tracks:
			return logical_block
	assert(false)

func get_next_block():
	if get_switch()!=null:
		return null
	var next_directed = get_next_tracks()
	if len(next_directed) == 0:
		return null
	assert(len(next_directed)==1)
	return next_directed[0].get_block()

func get_node_obj():
	var switch = get_switch()
	if switch != null:
		return switch
	return get_next_block()

func get_locked(turn=null):
	if turn==null:
		turn = get_next_turn()
	var locked_trainname = track.metadata[next_slot][turn]["locked"]
	if locked_trainname != null:
		return locked_trainname
	return null
