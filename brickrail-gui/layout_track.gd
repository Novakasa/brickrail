class_name LayoutTrack
extends Node2D

var slot0
var slot1
var pos0
var pos1
var connections = {}
var slots = ["N", "S", "E", "W"]
var slot_positions = {"N": Vector2(0.5,0), "S": Vector2(0.5,1), "E": Vector2(1,0.5), "W": Vector2(0,0.5)}

signal connections_changed

func _init(p_slot0, p_slot1):
	slot0 = p_slot0
	slot1 = p_slot1
	assert_slot_degeneracy()
	connections[slot0] = []
	connections[slot1] = []
	pos0 = slot_positions[slot0]
	pos1 = slot_positions[slot1]
	
	assert(slot0 != slot1)
	assert(slot0 in slots and slot1 in slots)

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

func connect_track(slot, track):
	if not slot in connections:
		push_error("[LayoutTrack] can't connect track to a nonexistent slot!")
		return
	if track == self:
		push_error("[LayoutTrack] can't connect track to itself!")
		return
	if track in connections[slot]:
		push_error("[LayoutTrack] track is already connected at this slot!")
		return
	# prints("connected a track", track.get_orientation(), "with this track", get_orientation())
	connections[slot].append(track)
	emit_signal("connections_changed", get_orientation())

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

func get_next_tracks_from(slot):
	return get_next_tracks_at(get_opposite_slot(slot))
	
func get_next_tracks_at(slot):
	return connections[slot]
	push_error("[LayoutTrack.get_next_tracks_at] track doesn't contain " + slot)
