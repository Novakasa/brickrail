
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
	legs = []
	var start_node = edges[0].from_node
	# add initial null leg
	legs.append(LayoutRouteLeg.new([LayoutEdge.new(null, start_node, "start")]))
	var travel_edges = []
	for edge in edges:
		if edge.type == "flip":
			legs.append(LayoutRouteLeg.new([edge]))
		if edge.type == "travel":
			travel_edges.append(edge)
			if edge.to_node.type=="block":
				legs.append(LayoutRouteLeg.new(travel_edges))
				travel_edges = []

func redirect_with_route(route):
	var from = get_current_leg().get_target()
	var start=null
	for i in range(len(route.legs)):
		if route.legs[i].get_from() == from:
			start=i
			break
	assert(start!=null)
	for i in range(len(legs)-current_leg-1):
		prints(legs[-1].get_from().id, legs[-1].get_target().id)
		legs[-1].decrement_marks()
		legs.remove(len(legs)-1)
	for i in range(len(route.legs)-start):
		legs.append(route.legs[i+start])
		legs[-1].increment_marks()

func recalculate_route(fixed_facing, trainname):
	var target_id = get_target_node().id
	var new_route = get_current_leg().get_target_node().calculate_routes(fixed_facing, trainname)[target_id]
	if new_route != null:
		redirect_with_route(new_route)

func get_start_node():
	return legs[0].get_start_node()

func get_target_node():
	return legs[-1].get_target_node()

func can_train_pass(trainname):
	var next_leg = get_next_leg()
	if next_leg == null:
		return false
	if next_leg.get_type() != "travel":
		return false
	return true

func get_blocking_trains():
	var next_leg = get_next_leg()
	if next_leg == null:
		return []
	if not next_leg.get_type()=="travel":
		return []
	return next_leg.get_locked()

func is_train_blocked(trainname):
	var next_leg = get_next_leg()
	if next_leg == null:
		return false
	if not next_leg.get_type()=="travel":
		return false
	if not next_leg.is_train_allowed(trainname):
		return true
	return false

func switch_and_lock_next(trainname):
	var next_leg = get_next_leg()
	next_leg.set_switches()
	next_leg.lock_tracks(trainname)

func advance_leg():
	current_leg += 1
	if current_leg<len(legs):
		legs[current_leg-1].decrement_marks()
		return legs[current_leg]
	current_leg -= 1
	return null

func get_next_leg():
	if not current_leg<len(legs)-1:
		return null
	return legs[current_leg+1]

func get_current_leg():
	return legs[current_leg]

func increment_marks():
	for i in range(len(legs)):
		if i<current_leg:
			continue
		legs[i].increment_marks()

func decrement_marks():
	for i in range(len(legs)):
		if i<current_leg:
			continue
		legs[i].decrement_marks()
