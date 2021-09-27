class_name LayoutEdge
extends Reference

var section
var from_node
var to_node
var weight
var type

func _init(p_from_node, p_to_node, p_type, p_section=null):
	from_node = p_from_node
	to_node = p_to_node
	section = p_section
	type = p_type
	if section!=null:
		weight = float(len(section.tracks))
	else:
		weight = 0.0

func get_locked():
	var locked = []
	if section != null:
		locked = section.get_locked()
	if to_node.type=="block":
		var locked_train = to_node.obj.get_locked()
		if locked_train != null and not locked_train in locked:
			locked.append(locked_train)
	return locked
