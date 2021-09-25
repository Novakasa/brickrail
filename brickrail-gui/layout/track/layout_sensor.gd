extends Reference
class_name LayoutSensor

var marker_color

signal marker_color_changed()
signal triggered(train)

func _init(p_marker_color=null):
	marker_color = p_marker_color

func get_color():
	if marker_color == null:
		return Color.white
	return marker_color.get_preview_color()

func get_colorname():
	if marker_color == null:
		return "none"
	return marker_color.colorname

func set_marker_color(p_marker_colorname):
	if marker_color != null:
		marker_color.disconnect("colors_changed", self, "_on_marker_colors_changed")
		marker_color.disconnect("removing", self, "_on_marker_color_removing")
	if p_marker_colorname == null:
		marker_color = null
	else:
		marker_color = Devices.colors[p_marker_colorname]
		marker_color.connect("colors_changed", self, "_on_marker_colors_changed")
		marker_color.connect("removing", self, "_on_marker_color_removing")
	emit_signal("marker_color_changed")

func _on_marker_colors_changed(colorname):
	emit_signal("marker_color_changed")

func _on_marker_color_removing(colorname):
	set_marker_color(null)

func serialize():
	var cname = null
	if marker_color != null:
		cname = marker_color.colorname
	return {"markername": cname}

func load(struct):
	var colorname = struct["markername"]
	if colorname == "default":
		colorname = null
	set_marker_color(colorname)

func trigger(train=null):
	emit_signal("triggered", train)
