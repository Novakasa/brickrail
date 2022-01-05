class_name LayoutRouteLeg
extends Reference

var edges
var full_section

func _init(p_edges):
	edges = p_edges

func get_start():
	return edges[0].from_node

func get_target():
	return edges[-1].to_node

func get_from():
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
		

func set_switches():
	var last_track = get_start().obj.section.tracks[-1]
	for edge in edges:
		if edge.section == null:
			continue
		for dirtrack in edge.section.tracks:
			dirtrack.track.set_switch_to_track(last_track.track)
			last_track.track.set_switch_to_track(dirtrack.track)
			last_track = dirtrack

func lock_tracks(trainname):
	get_full_section().set_track_attributes("locked", trainname, "<>")

func increment_marks():
	get_full_section().set_track_attributes("mark", 1, "<>", "increment")
	get_full_section().set_track_attributes("arrow", 1, ">")

func unlock_tracks():
	get_full_section().set_track_attributes("locked", null, "<>")

func decrement_marks():
	get_full_section().set_track_attributes("mark", -1, "<>", "increment")
	get_full_section().set_track_attributes("arrow", false, ">")

func get_locked():
	var locked = []
	var trainname = get_start().obj.get_locked()
	if trainname != null:
		locked.append(trainname)
	trainname = get_target().obj.get_locked()
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
