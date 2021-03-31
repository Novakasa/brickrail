class_name LayoutTrack
extends Node2D

var slots
var connections
var valid_slots = ["N", "S", "E", "W"]

func _init(p_slot0, p_slot1):
	assert(p_slot0 in valid_slots and p_slot1 in valid_slots)
	assert(p_slot0 != p_slot1)
	slots = {0: p_slot0, 1: p_slot1}

func get_opposite_slot(slot):
	if slots[0] == slot:
		return slot[1]
	if slots[1] == slot:
		return slot[0]
	push_error("[LayoutTrack.get_opposite_slot] track doesn't contain " + slot)

func get_next_tracks_from(slot):
	return get_next_tracks_at(get_opposite_slot(slot))
	
func get_next_tracks_at(slot):
	if slot == slot[0]:
		return connections[0]
	elif slot == slot[1]:
		return connections[1]
	push_error("[LayoutTrack.get_next_tracks_at] track doesn't contain " + slot)
