
class_name LayoutRoute
extends Reference

var edges = []

var legs = []

var length = 0.0
var current_leg = 0

func add_prev_edge(edge):
	edges.push_front(edge)
	length += edge.weight
	if len(edges)>1:
		assert(edges[0].to_node == edges[1].from_node)

func get_full_section():
	var section = LayoutSection.new()
	if edges[0].from_node.type=="block":
		section.append(edges[0].from_node.obj.section)
	for edge in edges:
		if edge.section != null:
			section.append(edge.section)
		if edge.to_node.type=="block":
			section.append(edge.to_node.obj.section)
	return section

func setup_legs():
	var travel_edges = []
	for edge in edges:
		if edge.type == "flip":
			legs.append(LayoutRouteLeg.new([edge]))
		if edge.type == "travel":
			travel_edges.append(edge)
			if edge.to_node.type=="block":
				legs.append(LayoutRouteLeg.new(travel_edges))
				travel_edges = []

func get_start():
	return legs[0].get_start()

func get_target():
	return legs[0].get_target()

func advance_leg():
	legs[current_leg].unlock()
	current_leg += 1
	if current_leg<len(legs):
		return legs[current_leg]
	current_leg -= 1
	return null

func get_current_leg():
	return legs[current_leg]
