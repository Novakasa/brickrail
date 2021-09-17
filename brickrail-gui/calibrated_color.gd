class_name CalibratedColor
extends VBoxContainer

var colors = []
var colorname
var type

var ColorEntry = load("res://color_entry.tscn")

signal removing(colorname)
signal colors_changed(colorname)

func setup(p_colorname, p_type):
	colorname = p_colorname
	type = p_type

func serialize():
	var struct = {}
	struct["colorname"] = colorname
	struct["type"] = type
	struct["colors"] = []
	for color in get_colors():
		struct["colors"].append(color.get_entry_color().to_html())
	return struct

func load(struct):
	for color_data in struct.colors:
		add_color(Color(color_data))

func add_color(p_color=null):
	var color = ColorEntry.instance()
	color.connect("tree_exited", self, "_on_color_removing")
	color.connect("color_changed", self, "_on_entry_color_changed")
	$VBoxContainer.add_child(color)
	if p_color!=null:
		color.set_entry_color(p_color)
	emit_signal("colors_changed", colorname)

func _on_color_removing():
	emit_signal("colors_changed", colorname)

func _on_entry_color_changed():
	emit_signal("colors_changed", colorname)

func remove():
	emit_signal("removing", colorname)
	queue_free()

func get_preview_color():
	var colors = $VBoxContainer.get_children()
	if len(colors) == 0:
		return Color.black
	return colors[0].get_entry_color()

func get_colors():
	return $VBoxContainer.get_children()

func get_pybricks_colors():
	var list = []
	for color in $VBoxContainer.get_children():
		var c = color.get_entry_color()
		list.append([int(c.h*360), int(c.s*100), int(c.v*100)])
	return list

func _on_PlusButton_pressed():
	add_color()
