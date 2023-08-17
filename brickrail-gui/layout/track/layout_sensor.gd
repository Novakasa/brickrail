extends Reference
class_name LayoutSensor

var marker_color
var highlight = 0

signal marker_color_changed()
signal highlight_changed()
signal triggered(train)

func _init(p_marker_color=null):
	marker_color = p_marker_color

func increment_highlight(val):
	highlight += val
	emit_signal("highlight_changed")

func get_color():
	if marker_color == null:
		return Color.white
	return Devices.marker_colors[marker_color]

func get_colorname():
	if marker_color == null:
		return "none"
	return marker_color

func set_marker_color(p_marker_colorname):
	marker_color = p_marker_colorname
	emit_signal("marker_color_changed")
	LayoutInfo.emit_signal("sensors_changed")

func serialize():
	var cname = null
	if marker_color != null:
		cname = marker_color
	return {"markername": cname}

func load(struct):
	var colorname = struct["markername"]
	if colorname == "default":
		colorname = null
	set_marker_color(colorname)

func trigger(train=null):
	emit_signal("triggered", train)
