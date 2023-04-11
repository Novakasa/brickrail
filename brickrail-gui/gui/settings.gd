tool
extends Node

var render_mode = "dynamic"
onready var layout_path = ProjectSettings.globalize_path("user://")

var colors = {
	"background": Color("161614"),
	"surface": Color("292929"),
	"primary": Color("E0A72E"),
	"secondary": Color("5C942E"),
	"tertiary": Color("91140F"),
	"white": Color("EEEEEE")}

signal render_mode_changed(mode)
signal colors_changed()

func _ready():
	print("settings ready")
	read_configfile()
	VisualServer.set_default_clear_color(colors["background"])

func set_color(cname, color):
	colors[cname] = color
	emit_signal("colors_changed")
	if cname == "background":
		VisualServer.set_default_clear_color(color)

func set_render_mode(mode):
	render_mode = mode
	emit_signal("render_mode_changed", render_mode)

func save_configfile():
	var data = {}
	data["colors"] = {}
	for colorname in colors:
		data.colors[colorname] = colors[colorname].to_html()
	data["render_mode"] = render_mode
	data["layout_path"] = layout_path
	var jsonstr = JSON.print(data, "\t")
	var configfil = File.new()
	configfil.open("user://config.json", File.WRITE)
	configfil.store_string(jsonstr)
	configfil.close()

func read_configfile():
	var dir = Directory.new()
	var _err = dir.open("user://")
	var exists = dir.file_exists("config.json")
	if not exists:
		emit_signal("render_mode_changed")
		emit_signal("colors_changed")
		return
	var configfil = File.new()
	configfil.open("user://config.json", File.READ)
	var jsonstr = configfil.get_as_text()
	configfil.close()
	
	var data = JSON.parse(jsonstr).result
	
	for colorname in data.colors:
		colors[colorname] = Color(data.colors[colorname])
	render_mode = data.render_mode
	if "layout_path" in data:
		layout_path = data.layout_path
	
	emit_signal("render_mode_changed")
	emit_signal("colors_changed")
