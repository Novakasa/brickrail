
class_name LayoutRoute
extends Reference

var edges = []
var length = 0.0

func add_prev_edge(edge):
	edges.push_front(edge)
	length += edge.weight
	if len(edges)>1:
		assert(edges[0].to_node == edges[1].from_node)

func get_full_section():
	var section = LayoutSection.new()
	for edge in edges:
		section.append(edge.section)
		if edge.to_node.obj.has_method("set_occupied"):
			section.append(edge.to_node.obj.section)
	return section
