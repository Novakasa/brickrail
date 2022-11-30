class_name LayoutRouteLeg
extends Reference

var edges
var full_section

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

func get_full_section():
	if full_section == null:
		full_section = LayoutSection.new()
		if edges[0].type=="start":
			return full_section
		if edges[0].from_node.type=="block":
			full_section.append(edges[0].from_node.obj.section)
		for edge in edges:
			if edge.section != null:
				full_section.append(edge.section)
			if edge.to_node.type=="block":
				full_section.append(edge.to_node.obj.section)
	return full_section

func get_sensor_list_from(start_dirtrack):
	var collecting = false
	var sensors = []
	for dirtrack in get_full_section().tracks:
		if collecting:
			if dirtrack.get_sensor() != null:
				var sensor_key = get_target_node().target.get_sensor_dirtrack_key(dirtrack)
				sensors.append([sensor_key, dirtrack.get_sensor()])
		if dirtrack == start_dirtrack:
			collecting = true

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
