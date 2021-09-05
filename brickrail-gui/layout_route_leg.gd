class_name LayoutRouteLeg
extends Reference

var edges

func _init(p_edges):
	edges = p_edges

func get_start():
	return edges[0].from_node

func get_target():
	return edges[-1].to_node

func get_type():
	return edges[0].type

func set_switches():
	var last_track = get_start().obj.section.tracks[-1]
	for edge in edges:
		print(edge.type)
		if edge.section == null:
			continue
		for dirtrack in edge.section.tracks:
			dirtrack.track.set_switch_to_track(last_track.track)
			last_track.track.set_switch_to_track(dirtrack.track)
			last_track = dirtrack
