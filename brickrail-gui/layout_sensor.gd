extends Reference
class_name LayoutSensor

var markername

signal marker_changed(markername)

func _init(p_markername):
	markername = p_markername

func get_color():
	return LayoutInfo.markers[markername]

func set_marker(p_markername):
	markername = p_markername
	emit_signal("marker_changed", markername)

func serialize():
	return {"markername": markername}

func load(struct):
	set_marker(struct["markername"])
