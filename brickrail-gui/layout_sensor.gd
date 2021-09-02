extends Reference
class_name LayoutSensor

var markername

signal marker_changed(markername)
signal train_detected(train)

func _init(p_markername=null):
	if p_markername==null:
		p_markername = LayoutInfo.markers.keys()[0]
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

func trigger(train=null):
	emit_signal("train_detected", train)
