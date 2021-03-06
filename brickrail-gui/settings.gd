tool
extends Node

var colors = {
	"background": Color("161614"),
	"surface": Color("292929"),
	"primary": Color("E0A72E"),
	"secondary": Color("5C942E"),
	"tertiary": Color("91140F"),
	"white": Color("EEEEEE")}

signal colors_changed()

func set_color(cname, color):
	colors[cname] = color
	emit_signal("colors_changed")
