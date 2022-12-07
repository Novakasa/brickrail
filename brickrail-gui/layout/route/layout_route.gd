
class_name LayoutRoute
extends Reference

var edges = []
var legs = []

var length = 0.0
var leg_index = 0

var trainname

signal completed()
signal can_advance()
signal target_entered(target_node)
signal target_in(target_node)
signal facing_flipped(facing)

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
	for i in range(len(legs)-leg_index-1):
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

func set_trainname(p_trainname):
	trainname = p_trainname
	
	update_intentions()
	LayoutInfo.connect("blocked_tracks_changed", self, "_on_LayoutInfo_blocked_tracks_changed")

func _on_LayoutInfo_blocked_tracks_changed(p_trainname):
	if p_trainname == trainname:
		return
	update_intentions()
	if can_advance():
		emit_signal("can_advance")

func collect_sensors():
	for leg in legs:
		if leg.get_type() == "start":
			continue
		leg.collect_sensor_list()

func update_intentions():
	for i in range(len(legs)):
		update_intention(i)

func update_intention(i):
	if i >= len(legs)-1:
		legs[i].set_intention("stop")
		return
	if legs[i+1].is_train_allowed(trainname):
		legs[i].set_intention("pass")
	else:
		legs[i].set_intention("stop")

func can_advance():
	if not get_current_leg().is_complete():
		return false
	if get_next_leg() == null:
		return true
	return get_next_leg().is_train_allowed(trainname)

func get_blocking_trains():
	var next_leg = get_next_leg()
	if next_leg == null:
		return []
	if not next_leg.get_type()=="travel":
		return []
	return next_leg.get_lock_trains()

func is_train_blocked():
	var next_leg = get_next_leg()
	if next_leg == null:
		return false
	if not next_leg.get_type()=="travel":
		return false
	if not next_leg.is_train_allowed(trainname):
		return true
	return false

func advance_leg():
	leg_index += 1
	if leg_index<len(legs):
		legs[leg_index-1].decrement_marks()
		return legs[leg_index]
	leg_index -= 1
	return null

func advance():
	var next_leg = get_next_leg()
	if not next_leg == null:
		if not next_leg.locked:
			next_leg.lock_and_switch(trainname)
	
	advance_leg()
	
	var current_leg = get_current_leg()
	print("next leg")
	prints("type:", current_leg.get_type())
	prints("intention:", current_leg.intention)
	print("sensors:")
	for i in range(len(current_leg.sensor_dirtracks)):
		prints(i, current_leg.sensor_keys[i], current_leg.sensor_dirtracks[i].id)
	
	if current_leg.get_type() == "flip":
		emit_signal("facing_flipped", current_leg.get_target_node().facing)
		if current_leg.intention == "pass":
			return "flip_cruise"
		return "flip_slow"
	return "cruise"

func advance_sensor(sensor_dirtrack):
	var current_leg = get_current_leg()
	assert(sensor_dirtrack == current_leg.get_next_sensor_dirtrack())
	
	var behavior = get_next_sensor_behavior()
	update_locks()
	
	current_leg.advance_sensor()
	
	if current_leg.is_complete():
		if current_leg.intention == "pass":
			behavior = advance()
		elif get_next_leg() == null:
			emit_signal("completed")
	
	return behavior

func update_locks():
	var current_leg = get_current_leg()
	var next_leg = get_next_leg()
	var key = current_leg.get_next_key()
	
	if key == "enter" and next_leg != null and current_leg.intention=="pass":
		next_leg.set_switches()
		next_leg.lock_tracks(trainname)
		emit_signal("target_entered", get_current_leg().get_target_node())
	
	if key == "in":
		current_leg.unlock_tracks()
		emit_signal("target_in", get_current_leg().get_target_node()) # this should lock the target block
	
	LayoutInfo.emit_signal("blocked_tracks_changed", trainname)

func get_next_sensor_behavior():
	var current_leg = get_current_leg()
	var next_leg = get_next_leg()
	
	var key = current_leg.get_next_key()
	if key == null:
		return "ignore"
	
	var please_stop = false
	if next_leg == null:
		please_stop = true
	elif current_leg.intention == "stop" or next_leg.get_type() == "flip":
		please_stop = true
	
	if not please_stop:
		return "ignore"
	
	if key == "enter":
		return "slow"
	if key == "in":
		return "stop"

	assert(false)

func get_next_leg():
	if not leg_index<len(legs)-1:
		return null
	return legs[leg_index+1]

func get_current_leg():
	return legs[leg_index]

func increment_marks():
	for i in range(len(legs)):
		if i<leg_index:
			continue
		legs[i].increment_marks()

func decrement_marks():
	for i in range(len(legs)):
		if i<leg_index:
			continue
		legs[i].decrement_marks()
