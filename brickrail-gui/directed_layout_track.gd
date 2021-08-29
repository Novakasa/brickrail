class_name DirectedLayoutTrack
extends Reference

var track
var next_slot
var prev_slot
var id

func _init(p_track, p_next_slot):
	track = p_track
	next_slot = p_next_slot
	prev_slot = track.get_opposite_slot(next_slot)
	id = p_track.id + "_>"+next_slot

func get_turns():
	return track.connections[next_slot].keys()

func get_next(segment=true):
	var next_track = track.get_next_track(next_slot, segment)
	if next_track == null:
		return null
	var next_prev_slot = track.get_neighbour_slot(next_slot)
	return next_track.get_directed_from(next_prev_slot)

func get_next_tracks():
	var next_tracks = []
	for next_track in track.connections[next_slot].values():
		next_tracks.append(next_track.get_directed_from(track.get_neighbour_slot(next_slot)))
	return next_tracks

func set_connection_attribute(slot, turn, key, value):
	track.set_connection_attribute(slot, turn, key, value)

func set_track_connection_attribute(to_track, key, value):
	track.set_track_connection_attribute(to_track.track, key, value)

func get_switch():
	return track.switches[next_slot]

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
