extends Node

func get_opposite_slot(slot):
	if slot == "N":
		return "S"
	if slot == "S":
		return "N"
	if slot == "E":
		return "W"
	if slot == "W":
		return "E"

func get_slot_pos(slot):
	return LayoutInfo.slot_positions[slot]
