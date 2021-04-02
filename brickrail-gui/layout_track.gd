class_name LayoutTrack
extends Node2D

var slot0
var slot1
var pos0
var pos1
var connections0 = []
var connections1 = []
var slots = ["N", "S", "E", "W"]
var slot_positions = {"N": Vector2(0.5,0), "S": Vector2(0.5,1), "E": Vector2(1,0.5), "W": Vector2(0,0.5)}

func _init(p_slot0, p_slot1):
	slot0 = p_slot0
	slot1 = p_slot1
	pos0 = slot_positions[slot0]
	pos1 = slot_positions[slot1]
	
	assert(slot0 != slot1)
	assert(slot0 in slots and slot1 in slots)

func distance_to(pos):
	var point = Geometry.get_closest_point_to_segment_2d(pos, pos0, pos1)
	return (point-pos).length()

func get_opposite_slot(slot):
	if slot0 == slot:
		return slot1
	elif slot1 == slot:
		return slot0
	push_error("[LayoutTrack.get_opposite_slot] track doesn't contain " + slot)

func get_next_tracks_from(slot):
	return get_next_tracks_at(get_opposite_slot(slot))
	
func get_next_tracks_at(slot):
	if slot == slot0:
		return connections0
	elif slot == slot1:
		return connections1
	push_error("[LayoutTrack.get_next_tracks_at] track doesn't contain " + slot)
