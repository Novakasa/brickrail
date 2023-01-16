
class_name LayoutRoute
extends Reference

var edges = []
var legs: Array = []

var length = 0.0
var leg_index = 0

var trainname = null
var highlighted=false

signal completed()
signal stopped()
signal can_advance()
signal target_entered(target_node)
signal target_in(target_node)
signal facing_flipped(facing)
signal intention_changed(leg_index, intention)
signal execute_behavior(behavior)

func add_prev_edge(edge):
	edges.push_front(edge)
	length += edge.weight
	if len(edges)>1:
		assert(edges[0].to_node == edges[1].from_node)

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
	var from = get_current_leg().get_target_node()
	var start=null
	for i in range(len(route.legs)):
		if route.legs[i].get_from_node() == from:
			start=i
			break
	assert(start!=null)
	unset_all_attributes()
	for i in range(len(legs)-leg_index-1):
		prints(legs[-1].get_from().id, legs[-1].get_target().id)
		legs.remove(len(legs)-1)
	for i in range(len(route.legs)-start):
		legs.append(route.legs[i+start])
	set_all_attributes()

	update_intentions()

func recalculate_route(fixed_facing):
	var target_id = get_target_node().id
	var new_route = get_current_leg().get_target_node().calculate_routes(fixed_facing, trainname)[target_id]
	if new_route != null:
		redirect_with_route(new_route)
		_on_LayoutInfo_blocked_tracks_changed(trainname)

func get_start_node():
	return legs[0].get_start_node()

func get_target_node():
	return legs[-1].get_target_node()

func set_trainname(p_trainname):
	if trainname != null:
		LayoutInfo.disconnect("blocked_tracks_changed", self, "_on_LayoutInfo_blocked_tracks_changed")
		unset_all_attributes()
	trainname = p_trainname

	if trainname != null:
		collect_sensors()
		update_intentions()
		LayoutInfo.connect("blocked_tracks_changed", self, "_on_LayoutInfo_blocked_tracks_changed")
		set_all_attributes()

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
	for i in range(leg_index, len(legs)):
		update_intention(i)

func update_intention(i):
	if i >= len(legs)-1:
		set_leg_intention(i, "stop")
		return
	if can_lock_leg(i+1):
		set_leg_intention(i, "pass")
	else:
		set_leg_intention(i, "stop")

func set_leg_intention(index, intention):
	var prev_intention = legs[index].intention
	legs[index].set_intention(intention)
	if intention != prev_intention:
		emit_signal("intention_changed", index, intention)
		if index == leg_index:
			_on_current_leg_intention_changed(prev_intention, intention)

func _on_current_leg_intention_changed(old_intention, new_intention):
	if get_current_leg().is_complete():
		return
	var prev_key = get_current_leg().get_prev_sensor_key()
	var next_type = null
	if get_next_leg() != null:
		next_type = get_next_leg().get_type()
	var old_behavior = get_sensor_behavior(prev_key, old_intention, next_type)
	var new_behavior = get_sensor_behavior(prev_key, new_intention, next_type)
	if new_behavior != old_behavior:
		emit_signal("execute_behavior", new_behavior)

	if get_current_leg().has_entered() and new_intention == "pass":
		lock_and_switch_next()

func can_advance():
	if not get_current_leg().is_complete():
		return false
	if get_next_leg() == null:
		return true
	return can_lock_leg(leg_index+1)

func get_blocking_trains():
	var next_leg = get_next_leg()
	if next_leg == null:
		return []
	var index = leg_index+1
	var blocking_trains = []
	while index<len(legs):
		var leg = legs[index]
		for blocking_train in leg.get_lock_trains():
			if blocking_train == trainname:
				continue
			if blocking_train in blocking_trains:
				continue
			blocking_trains.append(blocking_train)
		var greedy = not leg.get_target_node().obj.can_stop
		if leg.get_type() == "flip" and index < len(legs)-1:
			greedy = true
		if not greedy:
			break
		index += 1
	return blocking_trains

func is_train_blocked():
	if get_next_leg() == null:
		return false
	if not can_lock_leg(leg_index+1):
		return true
	return false

func can_lock_leg(index):
	while index<len(legs):
		var leg = legs[index]
		if not leg.can_lock(trainname):
			return false
		var greedy = not leg.get_target_node().obj.can_stop
		if leg.get_type() == "flip" and index < len(legs)-1:
			greedy = true
		if not greedy:
			return true
		index += 1

func lock_and_switch_next():
	var index = leg_index+1
	while index<len(legs):
		var leg = legs[index]
		leg.lock_and_switch(trainname)
		var greedy = not leg.get_target_node().obj.can_stop
		if leg.get_type() == "flip" and index < len(legs)-1:
			greedy = true
		if not greedy:
			break
		index += 1

func advance_attributes():
	legs[leg_index-1].set_attributes("arrow", -1, ">", "increment")
	legs[leg_index-1].set_attributes("mark", -1, "<>", "increment")
	if highlighted:
		legs[leg_index-1].set_attributes("highlight", -1, "<>", "increment")

func set_all_attributes():
	for i in range(len(legs)):
		if i<leg_index:
			continue
		legs[i].set_attributes("arrow", 1, ">", "increment")
		legs[i].set_attributes("mark", 1, "<>", "increment")
		if highlighted:
			legs[i].set_attributes("highlight", 1, "<>", "increment")

func unset_all_attributes():
	for i in range(len(legs)):
		if i<leg_index:
			continue
		legs[i].set_attributes("arrow", -1, ">", "increment")
		legs[i].set_attributes("mark", -1, "<>", "increment")
		if highlighted:
			legs[i].set_attributes("highlight", -1, "<>", "increment")

func advance_leg():
	leg_index += 1
	advance_attributes()
	if leg_index<len(legs):
		return legs[leg_index]
	leg_index -= 1
	return null

func advance():
	var next_leg = get_next_leg()
	if not next_leg == null:
		if not next_leg.locked:
			lock_and_switch_next()
			LayoutInfo.emit_signal("blocked_tracks_changed", trainname)
	
	advance_leg()
	
	var current_leg = get_current_leg()
	print("next leg")
	prints("type:", current_leg.get_type())
	prints("intention:", current_leg.intention)
	print("sensors:")
	for i in range(len(current_leg.sensor_dirtracks)):
		prints(i, current_leg.sensor_keys[i], current_leg.sensor_dirtracks[i].id)
	
	var behavior
	if current_leg.get_type() == "flip":
		emit_signal("facing_flipped", current_leg.get_target_node().facing)
		if current_leg.intention == "pass":
			behavior = "flip_cruise"
		else:
			behavior = "flip_slow"
	else:
		behavior = "cruise"
	emit_signal("execute_behavior", behavior)

func next_sensor_flips():
	if get_next_leg() == null:
		return false
	if get_current_leg().get_next_key() != "in":
		return false
	if get_next_leg().get_type() != "flip":
		return false
	return true

func get_next_sensor_track():
	return get_current_leg().get_next_sensor_dirtrack()

func get_next_key():
	return get_current_leg().get_next_key()

func advance_sensor(sensor_dirtrack):
	var current_leg = get_current_leg()
	assert(sensor_dirtrack == current_leg.get_next_sensor_dirtrack())
	
	# note:
	# possible that update_locks blocks the next leg by starting another train,
	# changing the current leg intention.
	# This is prevented if the next leg is already locked at this point, which
	# usually happens on "enter", but if passing is set only after "enter", next
	# leg currently won't be locked. This is why it would be nice to have
	# dynamic train behavior and leg locking if the intention changes after
	# the "enter" sensor. See issue #50

	update_locks()
	
	var behavior = get_next_sensor_behavior()
	current_leg.advance_sensor()
	
	if current_leg.is_complete():
		if current_leg.intention == "pass":
			assert(can_advance())
			advance()
			return
		if get_next_leg() == null:
			emit_signal("completed")
		else:
			emit_signal("stopped")
	
	emit_signal("execute_behavior", behavior)

func update_locks():
	var current_leg = get_current_leg()
	var next_leg = get_next_leg()
	var key = current_leg.get_next_key()
	
	if key == "enter" and next_leg != null:
		if current_leg.intention == "pass":
			lock_and_switch_next()
		emit_signal("target_entered", get_current_leg().get_target_node())
	
	if key == "in":
		current_leg.unlock_tracks()
		emit_signal("target_in", get_current_leg().get_target_node()) # this should lock the target block
	
	LayoutInfo.emit_signal("blocked_tracks_changed", trainname)

func get_next_sensor_behavior():
	var intention = get_current_leg().intention
	var next_type = null
	if get_next_leg() != null:
		next_type = get_next_leg().get_type()
	var key = get_current_leg().get_next_key()
	
	return get_sensor_behavior(key, intention, next_type)

func get_sensor_behavior(key, intention, next_type):
	if key == null:
		return "cruise"
	
	var please_stop = false
	if intention == "stop" or next_type == "flip":
		please_stop = true
	if not please_stop:
		return "cruise"
	
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

func set_highlight():
	unset_all_attributes()
	assert(not highlighted)
	highlighted=true
	set_all_attributes()

func clear_highlight():
	unset_all_attributes()
	assert(highlighted)
	highlighted=false
	set_all_attributes()
