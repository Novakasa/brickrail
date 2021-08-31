extends Reference
class_name LayoutSensor

var markername

func _init(p_markername):
	markername = p_markername

func get_color():
	return LayoutInfo.markers[markername]

func set_marker(p_markername):
	markername = p_markername
