class_name LayoutRouteLeg
extends Reference

var edges = []
var full_section = null
var sensor_dirtracks = []
var sensor_keys = []
var current_index = 0
var intention = "pass"
var locked = false

func _init(p_edges):
	edges = p_edges
	if get_type() == "start":
		current_index = 1

func get_start_node():
	return edges[0].from_node

func get_target_node():
	return edges[-1].to_node

func get_from_node():
	return edges[0].from_node

func get_type():
	return edges[0].type

func set_intention(intent):
	intention = intent

func advance_sensor():
	current_index += 1

func is_complete():
	return current_index >= len(self.sensor_dirtracks)

func get_prev_sensor_key():
	if current_index == 0:
		return null
	return sensor_keys[current_index-1]

func get_prev_sensor_dirtrack():
	if current_index == 0:
		return null
	return sensor_dirtracks[current_index-1]

func get_next_sensor_dirtrack():
	if current_index >= len(sensor_dirtracks):
		return null
	return sensor_dirtracks[current_index]

func get_next_key():
	return sensor_keys[current_index]

func has_entered():
	var enter_index = sensor_keys.find("enter")
	if enter_index == -1:
		return false
	return enter_index<current_index

func collect_sensor_list():
	var target_node = get_target_node()
	var start_node = get_start_node()
	if get_type() != "travel":
		sensor_keys.append("in")
		sensor_dirtracks.append(target_node.sensors.sensor_dirtracks["in"])
		return
	var skip = true
	for dirtrack in get_full_section().tracks:
		if dirtrack.get_sensor() != null:
			var start_key = start_node.sensors.get_sensor_dirtrack_key(dirtrack)
			if start_key == "in":
				skip=false
				continue
			if dirtrack in sensor_dirtracks or skip:
				continue
			var target_key = target_node.sensors.get_sensor_dirtrack_key(dirtrack)
			sensor_keys.append(target_key)
			sensor_dirtracks.append(dirtrack)
			if target_key == "in":
				return

func get_section(with_start_block):
	
	var section = LayoutSection.new()
	if get_type() == "start":
		return section
	
	if with_start_block and edges[0].from_node.type=="block":
		section.append(edges[0].from_node.obj.section)
	for edge in edges:
		if edge.section != null:
			section.append(edge.section)
		if edge.to_node.type=="block":
			section.append(edge.to_node.obj.section)
	
	return section

func get_full_section():
	if full_section == null:
		full_section = get_section(true)
	return full_section

func lock_and_switch(trainname):
	lock_tracks(trainname)
	set_switches()

func set_switches():
	var last_track = get_start_node().obj.section.tracks[-1]
	var forward_switches = []
	for dirtrack in get_section(false).tracks:
		var forward_switch = last_track.get_switch()
		if forward_switch != null:
			forward_switches.append(forward_switch)
			forward_switch.switch(dirtrack.get_turn())
		var backward_switch = dirtrack.get_opposite().get_switch()
		if backward_switch != null and not backward_switch in forward_switches:
			backward_switch.switch(last_track.get_opposite().get_turn())
		last_track = dirtrack

func lock_tracks(trainname):
	var lock_trains = get_lock_trains()
	assert(lock_trains==[trainname]) # only start block should be occupied (by this train)
	get_full_section().set_track_attributes("locked", trainname, "<>")
	locked = true

func unlock_tracks():
	get_full_section().set_track_attributes("locked", null, "<>")
	locked = false

func set_attributes(key, value, direction="<>", operation="set"):
	get_full_section().set_track_attributes(key, value, direction, operation)

func get_lock_trains():
	var locked_trains = []
	var trainname = get_start_node().obj.get_locked()
	if trainname != null:
		locked_trains.append(trainname)
	trainname = get_target_node().obj.get_locked()
	if trainname != null and not trainname in locked_trains:
		locked_trains.append(trainname)
	for trainname2 in get_full_section().get_locked():
		if not trainname2 in locked_trains:
			locked_trains.append(trainname2)
	return locked_trains

func can_lock(trainname):
	var leg_locked = get_lock_trains()
	if len(leg_locked)>0 and leg_locked != [trainname]:
		return false
	return true
