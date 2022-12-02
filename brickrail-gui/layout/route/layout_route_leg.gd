class_name LayoutRouteLeg
extends Reference

const PLAN_STOP = 0
const PLAN_PASSING = 1

var edges = []
var full_section = null
var sensor_dirtracks = []
var sensor_keys = []
var current_index = 0
var plan = PLAN_STOP

func _init(p_edges):
	edges = p_edges

func get_start_node():
	return edges[0].from_node

func get_target_node():
	return edges[-1].to_node

func get_from_node():
	return edges[0].from_node

func get_type():
	return edges[0].type

func advance_sensor():
	current_index += 1

func get_sensor_list(start_dirtrack):
	current_index = -1
	var target_node_sensors = get_target_node().sensors
	for dirtrack in get_section(false).tracks:
		if dirtrack.get_sensor() != null:
			sensor_keys.append(target_node_sensors.get_sensor_dirtrack_key(dirtrack))
			sensor_dirtracks.append(dirtrack)

func get_next_behavior():
	if current_index == len(sensor_dirtracks):
		return null
	if plan == PLAN_PASSING:
		return "ignore"
	var key = sensor_keys[current_index]
	if key == "enter":
		return "slow"
	if key == "in":
		return "stop"
	return "ignore"

func get_start_behavior():
	if current_index == len(sensor_dirtracks):
		return null
	if get_type() == "travel":
		return "cruise"
	if get_type() == "flip":
		return "flip_heading"

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

func get_full_section():
	if full_section == null:
		full_section = get_section(true)
	return full_section

func set_switches():
	var last_track = get_start_node().obj.section.tracks[-1]
	var forward_switches = []
	for edge in edges:
		if edge.section == null:
			continue
		for dirtrack in edge.section.tracks:
			var forward_switch = last_track.get_switch()
			if forward_switch != null:
				forward_switches.append(forward_switch)
				forward_switch.switch(dirtrack.get_turn())
			var backward_switch = dirtrack.get_opposite().get_switch()
			if backward_switch != null and not backward_switch in forward_switches:
				backward_switch.switch(last_track.get_opposite().get_turn())
			last_track = dirtrack

func lock_tracks(trainname):
	get_full_section().set_track_attributes("locked", trainname, "<>")

func increment_marks():
	get_full_section().set_track_attributes("mark", 1, "<>", "increment")
	get_full_section().set_track_attributes("arrow", 1, ">", "increment")

func unlock_tracks():
	get_full_section().set_track_attributes("locked", null, "<>")

func decrement_marks():
	get_full_section().set_track_attributes("mark", -1, "<>", "increment")
	get_full_section().set_track_attributes("arrow", -1, ">", "increment")

func get_locked():
	var locked = []
	var trainname = get_start_node().obj.get_locked()
	if trainname != null:
		locked.append(trainname)
	trainname = get_target_node().obj.get_locked()
	if trainname != null and not trainname in locked:
		locked.append(trainname)
	for trainname2 in get_full_section().get_locked():
		if not trainname2 in locked:
			locked.append(trainname2)
	return locked

func is_train_allowed(trainname):
	var leg_locked = get_locked()
	if len(leg_locked)>0 and leg_locked != [trainname]:
		return false
	return true
