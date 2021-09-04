class_name LayoutRouteLeg
extends Reference

var edges

func _init(p_edges):
	edges = p_edges

func get_start():
	return edges[0].from_node

func get_target():
	return edges[-1].to_node
