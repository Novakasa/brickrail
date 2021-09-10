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

func add_color():
	var color = ColorEntry.instance()
	color.connect("removing", self, "_on_color_removing")
	color.connect("color_changed", self, "_on_entry_color_changed")
	$VBoxContainer.add_child(color)
	emit_signal("colors_changed", colorname)

func _on_color_removing():
	emit_signal("colors_changed", colorname)

func _on_entry_color_changed():
	emit_signal("colors_changed", colorname)

func remove():
	emit_signal("removing", colorname)
	queue_free()

func get_preview_color():
	return get_children()[0].get_entry_color()

func get_pybricks_colors():
	var list = []
	for color in $VBoxContainer.get_children():
		var c = color.get_entry_color()
		list.append([int(c.h*360), int(c.s*100), int(c.v*100)])
	return list

func _on_PlusButton_pressed():
	add_color()
