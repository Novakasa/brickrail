class_name LayoutTrack
extends Node2D

var slot0
var slot1
var connections0 = []
var connections1 = []
var slots = ["N", "S", "E", "W"]

func _init(p_slot0, p_slot1):
	slot0 = p_slot0
	slot1 = p_slot1
	assert(slot0 != slot1)
	assert(slot0 in slots and slot1 in slots)

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
