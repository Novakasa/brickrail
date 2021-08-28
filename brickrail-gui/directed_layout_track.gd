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

func get_next(segment=true):
	var next_track = track.get_next_track(next_slot, segment)
	if next_track == null:
		return null
	var next_prev_slot = track.get_neighbour_slot(next_slot)
	return next_track.get_directed_from(next_prev_slot)

func set_connection_attribute(slot, turn, key, value):
	track.set_connection_attribute(slot, turn, key, value)

func set_track_connection_attribute(to_track, key, value):
	track.set_track_connection_attribute(to_track.track, key, value)