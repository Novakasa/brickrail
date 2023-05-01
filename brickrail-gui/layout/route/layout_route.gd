
class_name LayoutRoute
extends Reference

var edges = []
var legs: Array = []

var length = 0.0
var leg_index = 0

var trainname = null
var highlighted=false

var passing = true

var logging_module

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
	logging_module = "Route "+get_start_node().id+" -> " + get_target_node().id

func redirect_with_route(route):
	var from = get_current_leg().get_target_node()
	var start=null
	for i in range(len(route.legs)):
		if route.legs[i].get_from_node() == from:
			start=i
			break
	assert(start!=null)
	unset_all_attributes()
	for _i in range(len(legs)-leg_index-1):
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

func set_passing(value):
	Logger.info("[%s] set passing %s" % [logging_module, passing])
	passing = value
	update_intentions()

func get_start_node():
	return legs[0].get_target_node() # leg 0 is type "start" which has only a target

func get_target_node():
	return legs[-1].get_target_node()

func set_trainname(p_trainname):
	if trainname != null:
		LayoutInfo.disconnect("blocked_tracks_changed", self, "_on_LayoutInfo_blocked_tracks_changed")
		unset_all_attributes()
		for leg in legs:
			if leg.locked:
				leg.unlock_tracks()
	trainname = p_trainname

	if trainname != null:
		collect_sensors()
		update_intentions()
		var _err = LayoutInfo.connect("blocked_tracks_changed", self, "_on_LayoutInfo_blocked_tracks_changed")
		set_all_attributes()

func _on_LayoutInfo_blocked_tracks_changed(p_trainname):
	if p_trainname == trainname:
		return
	update_intentions()
	if can_advance():
		Logger.info("[%s] can advance triggered by %s blocked_tracks_changed" % [logging_module, p_trainname])
		emit_signal("can_advance")

func collect_sensors():
	for leg in legs:
		leg.collect_sensor_list()

func update_intentions():
	for i in range(leg_index, len(legs)):
		update_intention(i)

func update_intention(i):
	if not passing and not legs[i].has_entered() and not is_leg_greedy(i):
		set_leg_intention(i, "stop")
		return
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
		Logger.info("[%s] leg intention changed from %s to %s" % [logging_module, prev_intention, intention])
		emit_signal("intention_changed", index, intention)
		if index == leg_index:
			_on_current_leg_intention_changed(prev_intention, intention)

func _on_current_leg_intention_changed(old_intention, new_intention):
	Logger.info("[%s] current leg intention changed from %s to %s" % [logging_module, old_intention, new_intention])
	if get_current_leg().is_complete():
		return
	var prev_key = get_current_leg().get_prev_sensor_key()
	var prev_speed
	if get_current_leg().get_prev_sensor_dirtrack() == null:
		prev_speed = legs[leg_index-1].get_prev_sensor_dirtrack().sensor_speed
	else:
		prev_speed = get_current_leg().get_prev_sensor_dirtrack().sensor_speed
	var next_type = null
	if get_next_leg() != null:
		next_type = get_next_leg().get_type()
	var old_behavior = get_sensor_behavior(prev_key, prev_speed, old_intention, next_type)
	var new_behavior = get_sensor_behavior(prev_key, prev_speed, new_intention, next_type)
	if new_behavior != old_behavior:
		Logger.info("[%s] behavior changed from %s to %s by intention change" % [logging_module, old_behavior, new_behavior])
		emit_signal("execute_behavior", new_behavior)

	if get_current_leg().has_entered() and new_intention == "pass":
		lock_and_switch_next()

func can_advance():
	if not get_current_leg().is_complete():
		return false
	if get_next_leg() == null:
		return false
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
		if not is_leg_greedy(index):
			break
		index += 1
	return blocking_trains

func is_leg_greedy(index):
	if not legs[index].get_target_node().obj.can_stop:
		return true
	if legs[index].get_type() == "flip" and index < len(legs)-1:
		return true
	return false

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
		if not is_leg_greedy(index):
			return true
		index += 1

func lock_and_switch_next():
	Logger.info("[%s] lock and switch next" % [logging_module])
	var index = leg_index+1
	while index<len(legs):
		var leg = legs[index]
		if not leg.locked:
			leg.lock_and_switch(trainname)
		if not is_leg_greedy(index):
			break
		index += 1

func advance_attributes():
	# legs[leg_index-1].set_attributes("arrow", -1, ">", "increment")
	legs[leg_index-1].set_attributes("mark+", -1, ">", "increment")
	legs[leg_index-1].set_attributes("mark-", -1, "<", "increment")
	if highlighted:
		legs[leg_index-1].set_attributes("highlight", -1, "<>", "increment")

func set_all_attributes():
	for i in range(len(legs)):
		if i<leg_index:
			continue
		# legs[i].set_attributes("arrow", 1, ">", "increment")
		legs[i].set_attributes("mark+", 1, ">", "increment")
		legs[i].set_attributes("mark-", 1, "<", "increment")
		if highlighted:
			legs[i].set_attributes("highlight", 1, "<>", "increment")

func unset_all_attributes():
	for i in range(len(legs)):
		if i<leg_index:
			continue
		# legs[i].set_attributes("arrow", -1, ">", "increment")
		legs[i].set_attributes("mark+", -1, ">", "increment")
		legs[i].set_attributes("mark-", -1, "<", "increment")
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
	Logger.info("[%s] advance()" % [logging_module])
	var next_leg = get_next_leg()
	var lock_changed = false
	if not next_leg.locked:
		lock_and_switch_next()
		lock_changed = true
	var prev_leg = get_current_leg()
	assert(prev_leg != next_leg)
	
	advance_leg()
	if lock_changed:
		# delay emitting this signal so another train doesn't trigger us
		# advancing _again_, while this function is still running.
		# Emitting after advance_leg makes can_advance() return false, so there
		# will be no further calls.
		LayoutInfo.emit_signal("blocked_tracks_changed", trainname)
	var current_leg = get_current_leg()
	Logger.info("[%s] current leg - type: %s, intention: %s" % [logging_module, current_leg.get_type(), current_leg.intention])
	for i in range(len(current_leg.sensor_dirtracks)):
		Logger.debug("[%s] Sensor: %s, %s, %s" % [logging_module, i, current_leg.sensor_keys[i], current_leg.sensor_dirtracks[i].id])
	
	var behavior
	var speed = prev_leg.get_prev_sensor_dirtrack().sensor_speed
	if current_leg.get_type() == "flip":
		emit_signal("facing_flipped", current_leg.get_target_node().facing)
		if current_leg.intention == "pass":
			behavior = "flip_"+speed
		else:
			behavior = "flip_slow"
	else:
		behavior = speed
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
	Logger.info("[%s] advance_sensor: %s" % [logging_module, sensor_dirtrack.id])
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
		Logger.info("[%s] advance_sensor current leg complete!" % [logging_module])
		if current_leg.intention == "pass":
			assert(can_advance())
			advance()
			return
		if get_next_leg() == null:
			Logger.info("[%s] completed!" % [logging_module])
			emit_signal("completed")
		else:
			Logger.info("[%s] stopped!" % [logging_module])
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
	var speed = get_current_leg().get_next_sensor_dirtrack().sensor_speed
	
	return get_sensor_behavior(key, speed, intention, next_type)

func get_sensor_behavior(key, speed, intention, next_type):
	if key == null:
		return speed
	
	if not (intention == "stop" or next_type == "flip"):
		return speed
	
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
