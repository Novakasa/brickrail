
class_name LayoutRoute
extends Node

var target_block
var origin_block
var tracks
var markers
var lock

func set_lock(value):
	for track in tracks:
		track.set_route_lock(value)
	lock = value

func set_switch_positions():
	var prev_track = tracks[0]
	for track in tracks:
		if prev_track == track:
			continue
		var from_slot = track.get_connected_slot(prev_track)
		if prev_track.is_switch(from_slot):
			# prev_track.switch(track.get_) TODO
			pass
		prev_track = track
		

func can_lock():
	for track in tracks:
		if track.route_lock:
			return false
	return true

func get_length():
	pass
