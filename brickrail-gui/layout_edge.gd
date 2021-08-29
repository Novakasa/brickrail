class_name LayoutEdge
extends Reference

var section
var from_node
var to_node
var weight

func _init(p_from_node, p_section):
	from_node = p_from_node
	section = p_section
	to_node = p_section.tracks[-1].get_node_obj().node
	weight = float(len(p_section.tracks))
